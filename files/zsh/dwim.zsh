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
  dwim last         reprint the last @ result panel (also: ↑ on an empty prompt)
  dwim thinking     reprint the last @ run's live tool-call log (pipe to less)
  dwim new          start a fresh @ thread (forget the current conversation)
  dwim help         show this help

  @intent           ask the agent (fast model); @@intent uses the deep model

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
    last|replay)
      command cat "${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_result" 2>/dev/null \
        || print -u2 -Pr -- "%F{240}· no recent dwim result%f"
      return 0
      ;;
    thinking)
      command cat "${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_thinking" 2>/dev/null \
        || print -u2 -Pr -- "%F{240}· no recent dwim thinking log%f"
      return 0
      ;;
    new)
      typeset -g _DWIM_SESSION_ID="" _DWIM_SESSION_TURNS=0
      print -Pr -- "%F{244}· thread reset%f"
      return 0
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

# Parse an @-buffer into "<tier>\t<intent>". '@@' → deep, single '@' → fast.
_dwim_at_parse() {
  local buf="$1"
  if [[ "$buf" == @@* ]]; then
    print -r -- $'deep\t'"${buf#@@}"
  else
    print -r -- $'fast\t'"${buf#@}"
  fi
}

# --- @intent agent palette ---------------------------------------------------
# `_dwim_run_action <intent> [tier]`: ask the Claude agent, fzf-pick a command, load it.
# tier defaults to "fast"; "deep" routes dwim-action to the deep model tier.
_dwim_run_action() {
  local intent="$1" tier="${2:-fast}"
  [[ -z "$intent" ]] && return 1
  zmodload zsh/datetime 2>/dev/null
  # A leading "new " (from @new / @@new) forces a fresh thread this turn.
  local fresh=0
  if [[ "$intent" == new\ * ]]; then fresh=1; intent="${intent#new }"; fi
  local now=$EPOCHSECONDS
  # Continue this terminal's thread unless: forced fresh, no session yet, or idle >15m.
  local resume=""
  if (( fresh )) || [[ -z "$_DWIM_SESSION_ID" ]] || (( now - ${_DWIM_SESSION_TS:-0} > 900 )); then
    _DWIM_SESSION_ID=""; typeset -g _DWIM_SESSION_TURNS=0
  else
    resume="$_DWIM_SESSION_ID"
    print -Pr -- "%F{244}↳ thread (${_DWIM_SESSION_TURNS})%f"
  fi
  local sessfile="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/sess-$$"
  # dwim-action owns the live display: it streams the agent's tool calls (gray)
  # and prints the answer to stderr, which flows straight to the terminal here.
  # We only capture stdout — the tab-separated command candidates — for fzf.
  print -u2 ""                                        # fresh line below the committed @ command
  local thinkfile="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_thinking"
  local out rc=0
  setopt localtraps          # restore the INT trap when this function returns
  trap 'rc=130' INT          # Ctrl-C → mark cancelled, keep control (don't unwind)
  out="$(DWIM_TIER="$tier" DWIM_RESUME="$resume" DWIM_SESSION_FILE="$sessfile" \
         dwim-action "$intent" 2> >(tee "$thinkfile" >&2))"
  local child_rc=$?          # capture BEFORE the (( )) test below, which would
                              # otherwise clobber $? with its own (false) result
  (( rc == 130 )) || rc=$child_rc   # if the trap didn't fire, take the child's exit code
  trap - INT
  if (( rc == 130 )); then
    print -u2 -Pr -- "%F{244}⊘ cancelled%f"
    return 1                  # before thread-advance + picker: thread stays as-is
  fi
  # Capture this run's session id + advance the thread.
  typeset -g _DWIM_SESSION_ID="$(command cat "$sessfile" 2>/dev/null)"
  typeset -g _DWIM_SESSION_TURNS=$(( ${_DWIM_SESSION_TURNS:-0} + 1 ))
  typeset -g _DWIM_SESSION_TS=$now
  # Capture THIS run's model right after the call so a later @@ can't make the
  # panel label go stale (the shared last_model file is per-process global).
  local model; model="$(command cat "${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_model" 2>/dev/null)"
  [[ -z "$out" ]] && { print -u2 -Pr -- "%F{244}· no command to suggest%f"; return 1 }
  # Each line is "<plain-English description>\t<command>". fzf shows the
  # description; the raw command is previewed below (so you see exactly what
  # runs). Selecting loads the command onto the prompt — never auto-executes.
  # Append the "type your own" escape-hatch as the final candidate.
  # Whole literal in $'…' so BOTH the \n separator and the \t delimiter expand
  # (a single-quoted \t would stay literal and break --delimiter).
  out="$out"$'\n✎ type your own…\t__DWIM_CUSTOM__'
  local pick
  pick="$(printf '%s\n' "$out" | fzf --height '~45%' --reverse --border --margin 0,0,0,2 \
            --delimiter='\t' --with-nth=1 \
            --select-1 --exit-0 --prompt 'do › ' --pointer '▶' \
            --preview='printf "%s" {2}' \
            --preview-window='down,3,wrap,border-top' \
            --header 'pick what to do · Enter loads the command · Esc cancels')"
  if [[ -n "$pick" ]]; then
    local desc="${pick%%$'\t'*}" cmd="${pick##*$'\t'}"
    if [[ "$cmd" == "__DWIM_CUSTOM__" ]]; then
      _dwim_custom_dispatch "$model"
      return
    fi
    print -Pr -- "%F{110}▸%f ${desc}"        # echo the option you chose, then run it
    _dwim_execute_loop "$cmd" "$model"
  fi
}

# Route a line typed into the "✎ type your own" entry (decision C):
#   bare text  → run as a command through the execute loop (classify→consent→run)
#   @/@@ text  → a new agent turn on the same thread (via _dwim_at_parse)
_dwim_custom_route() {
  local line="$1" model="$2"
  [[ -z "$line" ]] && return 1
  if [[ "$line" == @* ]]; then
    local parsed; parsed="$(_dwim_at_parse "$line")"
    _dwim_run_action "${parsed#*$'\t'}" "${parsed%%$'\t'*}"
  else
    _dwim_execute_loop "$line" "$model"
  fi
}

# Prompt for one line, then route it. Read is separate from routing so the
# routing is unit-testable without a tty.
_dwim_custom_dispatch() {
  local model="$1" line=""
  print -u2 -Pn "%F{110}✎ %f"
  read -r line
  _dwim_custom_route "$line" "$model"
}

# Render captured output as a bordered panel with a status line + model tag.
# Also stashes the rendered panel to ~/.cache/dwim/last_result and arms the
# ↑-replay flag, so `dwim last` / ↑-on-empty-prompt can re-show it.
_dwim_panel() {
  local cmd="$1" body="$2" exit_code="$3" model="${4:-}"
  local rfile="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_result"
  local tag=""; [[ -n "$model" ]] && tag=" %F{244}· ${model}%f"
  local -a out
  out+=("$(print -Pr -- "%F{240}┌ ${cmd} %f")")
  [[ -n "$body" ]] && out+=("$(print -r -- "${body}" | sed 's/^/  /')")
  if [[ "$exit_code" == 0 ]]; then
    out+=("$(print -Pr -- "%F{240}└%f %F{34}✓%f${tag}")")
  else
    out+=("$(print -Pr -- "%F{240}└%f %F{196}✗ ${exit_code}%f${tag}")")
  fi
  printf '%s\n' "${out[@]}"                          # show now
  printf '%s\n' "${out[@]}" > "$rfile" 2>/dev/null   # stash for replay
  typeset -g _DWIM_REPLAY_FRESH=1
}

# Ask before running a mutating command. Returns 0 (run) / 1 (skip).
_dwim_confirm() {
  local cmd="$1" key
  print -u2 -Pn "%F{214}⚠ run:%f ${cmd}  %F{240}[Enter runs · Esc skips]%f "
  read -k key
  print -u2 ""
  [[ "$key" == $'\n' || "$key" == $'\r' ]]
}

# Drive run → observe → repair for a single starting command.
_dwim_execute_loop() {
  local cmd="$1" model="$2" steps=0
  local -a history_json
  while (( steps < 5 )); do
    (( steps++ ))
    local info; info="$(dwim-engine --run "$cmd")"
    local interactive read_only ran exit_code stdout stderr
    interactive="$(print -r -- "$info" | _dwim_json interactive)"
    read_only="$(print -r -- "$info" | _dwim_json read_only)"
    ran="$(print -r -- "$info" | _dwim_json ran)"
    exit_code="$(print -r -- "$info" | _dwim_json exit)"
    stdout="$(print -r -- "$info" | _dwim_json stdout)"
    stderr="$(print -r -- "$info" | _dwim_json stderr)"

    # Present interactive tool → hand full-screen to your shell (you Enter).
    # (A MISSING interactive tool comes back exit 127 and falls through to repair.)
    if [[ "$interactive" == "true" && "$exit_code" != "127" ]]; then
      _dwim_load "$cmd"
      return 0
    fi
    # Mutating command not yet run → confirm, then force-run and re-read result.
    if [[ "$interactive" != "true" && "$ran" != "true" ]]; then
      _dwim_confirm "$cmd" || { print -u2 -Pr -- "%F{240}· skipped%f"; return 1 }
      info="$(dwim-engine --run "$cmd" --force)"
      exit_code="$(print -r -- "$info" | _dwim_json exit)"
      stdout="$(print -r -- "$info" | _dwim_json stdout)"
      stderr="$(print -r -- "$info" | _dwim_json stderr)"
    fi

    _dwim_panel "$cmd" "${stdout:-$stderr}" "$exit_code" "$model"
    [[ "$exit_code" == 0 ]] && return 0

    # Failure → repair (deterministic install / Claude), pick, loop.
    history_json+=("{\"cmd\":$(_dwim_jstr "$cmd"),\"exit\":${exit_code:-1},\"stdout\":$(_dwim_jstr "$stdout"),\"stderr\":$(_dwim_jstr "$stderr")}")
    local cands
    cands="$(print -r -- "[${(j:,:)history_json}]" | dwim-engine --repair)"
    [[ -z "$cands" ]] && { print -u2 -Pr -- "%F{240}· no fix found%f"; return 1 }
    local pick
    pick="$(printf '%s\n' "$cands" | fzf --height '~40%' --reverse --border \
              --delimiter='\t' --with-nth=1 --select-1 --exit-0 \
              --prompt 'fix › ' --pointer '▶' \
              --preview='printf "%s" {2}' --preview-window='down,3,wrap,border-top' \
              --header 'apply a fix · Enter runs · Esc stops')"
    [[ -z "$pick" ]] && return 1
    cmd="${pick##*$'\t'}"
  done
  print -u2 -Pr -- "%F{240}· gave up after 5 steps%f"
  return 1
}

# Tiny JSON field readers (avoid a jq dependency; values are simple).
_dwim_json() { "${DWIM_PYTHON:-$HOME/.venvs/dwim/bin/python}" -c '
import sys, json
key = sys.argv[1]
try: v = json.load(sys.stdin).get(key, "")
except Exception: v = ""
if v is None: v = ""
elif isinstance(v, bool): v = "true" if v else "false"
print(v)' "$1" }
_dwim_jstr() { "${DWIM_PYTHON:-$HOME/.venvs/dwim/bin/python}" -c '
import sys, json; print(json.dumps(sys.argv[1]))' "$1" }

# accept-line wrapper: a line starting with '@' is an agent intent, not a
# command. Delegates to whatever accept-line is currently installed (builtin
# or a plugin wrapper like zsh-syntax-highlighting's/zsh-autosuggestions')
# rather than the bare builtin, so we add @-detection without clobbering
# other Enter-time behavior regardless of plugin load order.
_dwim_at_accept() {
  if [[ "$BUFFER" == @* ]]; then
    local parsed tier intent
    parsed="$(_dwim_at_parse "$BUFFER")"
    tier="${parsed%%$'\t'*}"
    intent="${parsed#*$'\t'}"
    BUFFER=""
    zle _dwim_orig_accept_line     # end the (now empty) line via the real widget
    _dwim_run_action "$intent" "$tier"
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

# ↑ on an EMPTY prompt right after an @ run replays the last result panel; every
# other time it's plain history. The fresh flag is armed when a panel renders and
# cleared on the next command (preexec) or after one replay, so history nav is
# never permanently hijacked. We call the BUILTIN via `.up-line-or-history`, so
# there's no wrap cycle even if re-sourced.
_dwim_replay_up() {
  if [[ -z "$BUFFER" && -n "$_DWIM_REPLAY_FRESH" ]]; then
    _DWIM_REPLAY_FRESH=""
    zle -I
    command cat "${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_result" 2>/dev/null
    zle reset-prompt
    return
  fi
  zle .up-line-or-history
}
autoload -Uz add-zsh-hook 2>/dev/null
_dwim_clear_replay() { _DWIM_REPLAY_FRESH=""; }
add-zsh-hook preexec _dwim_clear_replay 2>/dev/null
if [[ -z "$_DWIM_UP_INSTALLED" ]]; then
  zle -N up-line-or-history _dwim_replay_up
  typeset -g _DWIM_UP_INSTALLED=1
fi

