# dwim — correct the last failed command via a local LLM.
# Records the last command + exit code, then `dwim` asks the engine to fix it
# and loads the suggestion onto your command line (never auto-runs).

typeset -g _DWIM_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last"
typeset -g _DWIM_LAST_CMD=""
typeset -g _DWIM_GHOST=""   # armed correction, shown as grey ghost text
typeset -g DWIM_ICON="${DWIM_ICON:-✨}"   # prefix on the suggestion line; set to taste

_dwim_preexec() {
  _DWIM_GHOST=""   # any command running clears a pending suggestion
  case "$1" in
    dwim|dwim\ *) _DWIM_LAST_CMD="" ;;   # never try to fix dwim itself
    *)            _DWIM_LAST_CMD="$1" ;;
  esac
}

_dwim_precmd() {
  local code=$?
  [[ -z "$_DWIM_LAST_CMD" ]] && return
  local cmd="$_DWIM_LAST_CMD"
  _DWIM_LAST_CMD=""
  mkdir -p "${_DWIM_STATE:h}"
  print -r -- "$code" >  "$_DWIM_STATE"
  print -r -- "$cmd"  >> "$_DWIM_STATE"

  # Autonomous mode: on command-not-found (127), auto-suggest a correction via
  # the warm daemon and load it onto the prompt. `print -z` works here (precmd),
  # unlike in command_not_found_handler. Manual `dwim` still handles other codes.
  [[ "$code" == 127 ]] || return
  local errdest=/dev/null
  [[ -n "$DWIM_DEBUG" ]] && errdest=/tmp/dwim.log
  local fix
  fix="$(dwim-engine --cmd "$cmd" --exit 127 --daemon-only 2>>"$errdest")"
  local rc=$?
  if (( rc == 0 )) && [[ -n "$fix" && "$fix" != "$cmd" ]]; then
    _DWIM_GHOST="$fix"   # armed; Tab on the empty prompt fills it in
    # Grey preview line above the prompt (reliable — doesn't fight autosuggestions).
    print -Pr -- "%F{244}${DWIM_ICON} ${fix}%f  %F{240}· Tab to accept%f"
  elif (( rc == 4 )) && [[ -n "${commands[dwim-daemon]}" ]]; then
    # Daemon not up yet — warm it in the background for next time.
    (nohup dwim-daemon >/tmp/dwim-daemon.log 2>&1 &)
    print -u2 "dwim: warming corrector in background — kicks in shortly"
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _dwim_preexec
# Register our precmd FIRST so $? is the real last exit code, before starship
# (which clobbers $? inside its own precmd) runs.
precmd_functions=(_dwim_precmd ${precmd_functions:#_dwim_precmd})

# Default buffer-load seam; overridden in tests.
_dwim_load() { print -z -- "$1" }

# Trace to /tmp/dwim.log when DWIM_DEBUG is set (export DWIM_DEBUG=1).
_dwim_dbg() { [[ -n "$DWIM_DEBUG" ]] && print -r -- "[dwim] $*" >> /tmp/dwim.log }

dwim() {
  case "$1" in
    help|-h|--help)
      print -r -- "dwim — local-LLM shell command corrector

USAGE
  dwim              correct the last failed command; loads the fix onto your
                    prompt (press Enter to run). Auto-fires on command-not-found.
  dwim status       show the active model, daemon state, and device
  dwim models       list configured models (correct/action) + connection state
  dwim help         show this help

HOW IT WORKS
  A typo'd command (command not found) auto-suggests a fix via a warm local
  MLX model — no typing needed. For commands that ran but failed (bad flags,
  exit != 0), run 'dwim' yourself to get a correction.

CONFIG
  ~/.config/dwim/config.toml   set 'model = \"...\"' to change the model
  DWIM_DEBUG=1                 trace to /tmp/dwim.log"
      return 0
      ;;
    status)
      dwim-engine --status
      return $?
      ;;
    models)
      dwim-engine --models
      return $?
      ;;
  esac
  _dwim_dbg "--- dwim invoked; state=$_DWIM_STATE"
  if [[ ! -f "$_DWIM_STATE" ]]; then
    _dwim_dbg "no state file"
    print -u2 "dwim: nothing to fix"
    return 1
  fi
  local code cmd suggestion
  code="$(sed -n 1p "$_DWIM_STATE")"
  cmd="$(sed -n '2,$p' "$_DWIM_STATE")"
  _dwim_dbg "read state: code=[$code] cmd=[$cmd]"
  # Only worth loading the model when the last command actually failed.
  if [[ "$code" == "0" ]]; then
    _dwim_dbg "exit 0 → skip"
    print -u2 "dwim: last command succeeded — nothing to fix"
    return 1
  fi
  # Keep the engine's stderr OFF the tty — MLX/Metal load writes control chars
  # that corrupt the line editor, so `print -z` below wouldn't render.
  local errdest=/dev/null
  [[ -n "$DWIM_DEBUG" ]] && errdest=/tmp/dwim.log
  suggestion="$(dwim-engine --cmd "$cmd" --exit "$code" 2>>"$errdest")"
  local rc=$?
  _dwim_dbg "engine rc=$rc suggestion=[$suggestion]"
  if (( rc != 0 )) || [[ -z "$suggestion" ]]; then
    _dwim_dbg "no suggestion → bail"
    print -u2 "dwim: no correction found"
    return 1
  fi
  _dwim_dbg "loading onto buffer via print -z"
  _dwim_load "$suggestion"
}

# --- Accept an armed suggestion with Tab -------------------------------------
# The autonomous path prints a grey preview line and arms $_DWIM_GHOST. On the
# (empty) prompt, Tab fills the correction into the buffer; otherwise Tab does
# normal completion. (Inline POSTDISPLAY ghost fights zsh-autosuggestions, which
# owns POSTDISPLAY — so we use a printed grey preview + Tab instead.)
_dwim_tab_widget() {
  if [[ -n "$_DWIM_GHOST" && -z "$BUFFER" ]]; then
    BUFFER="$_DWIM_GHOST"
    CURSOR=${#BUFFER}
    _DWIM_GHOST=""
  else
    zle expand-or-complete
  fi
}
zle -N _dwim_tab_widget
bindkey '^I' _dwim_tab_widget      # Tab accepts the armed fix (or completes)

# --- @intent agent palette ---------------------------------------------------
# `_dwim_run_action <intent>`: ask the Claude agent, fzf-pick a command, load it.
_dwim_run_action() {
  local intent="$1"
  [[ -z "$intent" ]] && return 1
  # dwim-action owns the live display: it streams the agent's tool calls (gray)
  # and prints the answer to stderr, which flows straight to the terminal here.
  # We only capture stdout — the tab-separated command candidates — for fzf.
  print -u2 ""                                        # fresh line below the committed @ command
  local out; out="$(dwim-action "$intent")"
  [[ -z "$out" ]] && { print -u2 -Pr -- "%F{244}· no command to suggest%f"; return 1 }
  # Each line is "<plain-English description>\t<command>". fzf shows the
  # description; the raw command is previewed below (so you see exactly what
  # runs). Selecting loads the command onto the prompt — never auto-executes.
  local pick
  pick="$(printf '%s\n' "$out" | fzf --height '~45%' --reverse --border --margin 0,0,0,2 \
            --delimiter='\t' --with-nth=1 \
            --select-1 --exit-0 --prompt 'do › ' --pointer '▶' \
            --preview='printf "%s" {2}' \
            --preview-window='down,3,wrap,border-top' \
            --header 'pick what to do · Enter loads the command · Esc cancels')"
  [[ -n "$pick" ]] && _dwim_load "${pick##*$'\t'}"
}

# accept-line wrapper: a line starting with '@' is an agent intent, not a
# command. Delegates to whatever accept-line is currently installed (builtin
# or a plugin wrapper like zsh-syntax-highlighting's/zsh-autosuggestions')
# rather than the bare builtin, so we add @-detection without clobbering
# other Enter-time behavior regardless of plugin load order.
_dwim_at_accept() {
  if [[ "$BUFFER" == @* ]]; then
    local intent="${BUFFER#@}"
    BUFFER=""
    zle _dwim_orig_accept_line     # end the (now empty) line via the real widget
    _dwim_run_action "$intent"
    return
  fi
  zle _dwim_orig_accept_line
}

# Idempotent via a one-time install flag — NOT a widgets[accept-line] identity
# check. A neighbor plugin (e.g. zsh-syntax-highlighting) may legitimately wrap
# accept-line on top of ours between sources, so accept-line won't point at
# _dwim_at_accept even though we're already installed. Re-capturing in that
# case would alias _dwim_orig_accept_line onto the neighbor's wrapper, which
# itself delegates back through us — a 2-hop cycle that infinite-loops on
# Enter. The flag decouples "have we installed" from "what's on top now".
if [[ -z "$_DWIM_ACCEPT_INSTALLED" ]]; then
  zle -A accept-line _dwim_orig_accept_line
  zle -N accept-line _dwim_at_accept
  typeset -g _DWIM_ACCEPT_INSTALLED=1
fi

