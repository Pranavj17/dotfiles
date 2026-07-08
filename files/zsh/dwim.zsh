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
    @*)           _DWIM_LAST_CMD="" ;;   # @intent is an agent request, not a typo
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
  dwim personas     list @ personas (prompt-only domain experts) + their dir
  dwim index <dirs> build/update the local RAG index over <dirs> so @ can ground
                    answers in your own notes/code, e.g. dwim index ~/Documents/helixa
                    (no default — indexing all of ~/Documents is 30k+ files)
  dwim last         reprint the last @ result panel (also: ↑ on an empty prompt)
  dwim thinking     reprint the last @ run's live tool-call log (pipe to less)
  dwim new          start a fresh @ thread (forget the current conversation)
  dwim help         show this help

  @intent           ask the agent (fast model); @@intent uses the deep model
  @<persona> intent add a domain expert's system prompt (see 'dwim personas'),
                    e.g. @git undo my last commit — word-1 must match exactly

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
    index)
      shift
      dwim-engine --index "$@"    # build/update the local RAG index (default: ~/Documents)
      return $?
      ;;
    personas)
      dwim-engine --personas
      return $?
      ;;
    last|replay)
      command cat "${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_result" 2>/dev/null \
        || print -u2 -Pr -- "%F{240}· no recent dwim result%f"
      return 0
      ;;
    thinking)
      local _tf="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_thinking"
      # The trace only holds TOOL calls. A self-contained @ answer (a table, a
      # write, a knowledge reply) uses no tools, so the file exists but is empty —
      # cat would print nothing at all. Distinguish empty (no tools) from missing
      # (no run yet) so it never reads as silently broken.
      if [[ -s "$_tf" ]]; then
        command cat "$_tf"
      elif [[ -f "$_tf" ]]; then
        print -u2 -Pr -- "%F{240}· last @ answer used no tools — nothing to trace%f"
      else
        print -u2 -Pr -- "%F{240}· no recent @ run%f"
      fi
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
  setopt localoptions no_xtrace no_verbose   # never leak dwim internals under `set -x`
  local intent="$1" tier="${2:-fast}"
  [[ -z "$intent" ]] && return 1
  zmodload zsh/datetime 2>/dev/null
  # A leading "new " (from @new / @@new) forces a fresh thread this turn.
  local fresh=0
  if [[ "$intent" == new\ * ]]; then fresh=1; intent="${intent#new }"; fi
  # Agentic-loop offer: only for a plain fast @ with a task-shaped intent (not
  # @@ deep, not @persona — a persona's name is word-1 so it never classifies as
  # a task). The engine classifies locally; a miss costs one keystroke and falls
  # through to the normal read-only answer below, so this never blocks a question.
  if [[ "$tier" == fast ]]; then
    local _kind
    _kind=$(dwim-engine --classify "$intent" 2>/dev/null)
    if [[ "$_kind" == task ]]; then
      print -u2 -Pr -- "  %F{240}⤷ looks like a task, not a question.%f"
      # One keypress (no Enter), same idiom as _dwim_confirm's read -k so it stays
      # driveable from stdin: y/Y accepts the do-loop, anything else declines.
      local _ans
      print -u2 -n -- "  plan it as a do-loop? [y/N] "
      read -k -u0 _ans   # -u0: one keypress from fd 0 (the tty interactively)
      print -u2 ""
      if [[ "$_ans" == [yY] ]]; then
        local _planout _pf
        _planout=$(dwim-engine --plan "$intent")
        print -r -- "${_planout%$'\n'DWIM_PLAN_READY *}"   # show plan, hide sentinel line
        _pf=$(print -r -- "$_planout" | sed -n 's/^DWIM_PLAN_READY //p')
        if [[ -n "$_pf" ]]; then
          if _dwim_confirm "approve & run this plan?"; then
            dwim-engine --do --plan-file "$_pf"
          else
            print -u2 -Pr -- "  %F{240}cancelled.%f"
          fi
        fi
        return 0
      fi
      # declined → fall through to the normal read-only answer below
    fi
  fi
  local now=$EPOCHSECONDS
  # Continue this terminal's thread unless: forced fresh, no session yet, or idle >15m.
  local resume=""
  if (( fresh )) || [[ -z "$_DWIM_SESSION_ID" ]] || (( now - ${_DWIM_SESSION_TS:-0} > 900 )); then
    _DWIM_SESSION_ID=""; typeset -g _DWIM_SESSION_TURNS=0
  else
    resume="$_DWIM_SESSION_ID"
    # Thread continuity is shown IN the engine's spinner/breadcrumb (via
    # DWIM_THREAD below), not as a separate line glued to the typed command.
  fi
  local sessfile="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/sess-$$"
  # dwim-action owns the live display: it streams the agent's tool calls (gray)
  # and prints the answer to stderr, which flows straight to the terminal here.
  # We only capture stdout — the tab-separated command candidates — for fzf.
  # stderr flows straight to the terminal: the engine draws a live spinner there
  # that collapses to a one-line breadcrumb, and writes the full call+output
  # trace to last_thinking itself (so `dwim thinking` still works — no tee here,
  # which used to dump the whole gray wall onto the screen).
  print -u2 ""                                        # fresh line below the committed @ command
  local out rc=0
  setopt localtraps          # restore the INT trap when this function returns
  trap 'rc=130' INT          # Ctrl-C → mark cancelled, keep control (don't unwind)
  out="$(DWIM_TIER="$tier" DWIM_RESUME="$resume" DWIM_SESSION_FILE="$sessfile" \
         DWIM_THREAD="$_DWIM_SESSION_TURNS" dwim-action "$intent")"
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
  # No candidates → the ✦ answer above IS the result (e.g. a text/explain task).
  # Nothing to pick; return 0 (not a failure) so $? stays clean — a non-zero here
  # reddens the prompt and breaks `@question && next`. No footer: the answer speaks.
  [[ -z "$out" ]] && return 0
  # Each line is "<plain-English description>\t<command>". fzf shows the
  # description; the raw command is previewed below (so you see exactly what
  # runs). Selecting loads the command onto the prompt — never auto-executes.
  # `--print-query` lets you just TYPE a command (or an @intent) and Enter — even
  # when it matches none of the listed suggestions — instead of a two-step "type
  # your own" entry. fzf prints the typed query on line 1; a chosen candidate (if
  # any) follows on line 2. NO --exit-0/--select-1: those made a non-matching
  # query silently exit with nothing (the "dwim quit" bug).
  local fzf_out fzf_rc query sel
  fzf_out="$(printf '%s\n' "$out" | fzf --height '~45%' --reverse --border --margin 0,0,0,2 \
            --delimiter='\t' --with-nth=1 --print-query \
            --prompt 'pick › or type to ask · ' --pointer '▶' \
            --preview='printf "%s" {2}' \
            --preview-window='down,3,wrap,border-top' \
            --header 'pick one · TYPE to ask the agent · !cmd runs a command · Esc cancels')"
  fzf_rc=$?
  # Esc / Ctrl-C (130) cancels — do NOT run the typed query. --print-query prints
  # it even on abort, so we must gate on the exit code. 0 = a candidate selected,
  # 1 = typed text accepted with no match (run it); 130 = aborted (cancel).
  (( fzf_rc == 130 )) && { print -u2 -Pr -- "%F{240}· cancelled%f"; return 1 }
  query="${fzf_out%%$'\n'*}"
  sel=""
  [[ "$fzf_out" == *$'\n'* ]] && sel="${fzf_out#*$'\n'}"
  if [[ -n "$sel" ]]; then
    local desc="${sel%%$'\t'*}" cmd="${sel##*$'\t'}"
    print -Pr -- "%F{110}▸%f ${desc}"        # echo the option you chose, then run it
    _dwim_execute_loop "$cmd" "$model"
  elif [[ -n "$query" ]]; then
    # Typed text that matched no suggestion → route it: bare prose asks the agent,
    # !cmd runs a literal command, @/@@ starts a new agent turn on the thread.
    print -Pr -- "%F{110}▸%f ${query}"
    _dwim_custom_route "$query" "$model"
  fi
}

# Route a line you TYPED into the picker:
#   @/@@ text  → a new agent turn on the same thread (fast / deep)
#   !command   → run that exact command (classify → consent → run)
#   bare text  → a follow-up question to the agent (fast). Typing prose into the
#                palette ASKS — it is NOT shoved through /bin/sh (which is how
#                "show me" became `show: command not found`). Use ! to run a
#                literal command you typed.
_dwim_custom_route() {
  setopt localoptions no_xtrace no_verbose
  local line="$1" model="$2"
  [[ -z "$line" ]] && return 1
  if [[ "$line" == @* ]]; then
    local parsed; parsed="$(_dwim_at_parse "$line")"
    _dwim_run_action "${parsed#*$'\t'}" "${parsed%%$'\t'*}"
  elif [[ "$line" == '!'* ]]; then
    _dwim_execute_loop "${${line#\!}# }" "$model"   # explicit: run this exact command
  else
    _dwim_run_action "$line" fast                    # bare prose → ask the agent
  fi
}

# Render captured output as a bordered panel with a status line + model tag.
# Also stashes the rendered panel to ~/.cache/dwim/last_result and arms the
# ↑-replay flag, so `dwim last` / ↑-on-empty-prompt can re-show it.
_dwim_panel() {
  local cmd="$1" body="$2" exit_code="$3" model="${4:-}" dur="${5:-}" cmd_hl="${6:-}"
  local rfile="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_result"
  local tag=""; [[ -n "$model" ]] && tag=" %F{244}· ${model}%f"
  # Show how long the command took (e.g. "· 0.34s") when the engine reported it.
  [[ -n "$dur" ]] && tag=" %F{244}· ${dur}s%f${tag}"
  local -a out
  local g=$'\033[38;5;240m' n=$'\033[0m'
  # Header shows the syntax-highlighted command when supplied (DISPLAY ONLY —
  # lossless, strips back to $cmd; nothing here executes it), else the raw $cmd.
  # cmd_hl carries its own \033[…m escapes; the trailing ${n} resets so the gray
  # border colour is restored regardless. See _dwim_confirm for the -r rationale.
  local shown="${cmd_hl:-$cmd}"
  out+=("${g}┌ ${shown} ${n}")                        # cmd RAW/highlighted — see _dwim_confirm
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
  local cmd="$1" cmd_hl="$2" key
  # Show the syntax-highlighted command when we have one, else the raw command.
  # DISPLAY ONLY — cmd_hl is lossless (strips back to $cmd) and nothing here runs
  # it; the caller runs the raw $cmd. read -k only reads a keypress.
  local shown="${cmd_hl:-$cmd}"
  # dwim-write writes the last @ answer (out-of-band, not in the command), so the
  # generic consent line can't show WHAT gets written. Preview it: target path,
  # NEW vs OVERWRITES, and the first 3 lines of the answer to be written.
  if [[ "$cmd" == dwim-write\ * ]]; then
    # Parse <path> the way the shell will — (z) shell-word-splits (respects quotes),
    # (Q) strips one quote level — so the previewed path matches what bin/dwim-write
    # actually writes (naive prefix-strip mis-parsed a quoted/tilde/spaced path).
    local -a _w; _w=(${(z)cmd}); local wp="${(Q)_w[2]}"; wp="${wp/#\~/$HOME}"
    local la="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_answer"
    local status_line
    if [[ -f "$wp" ]]; then
      status_line=$'\033[38;5;214m⚠ OVERWRITES\033[0m ('"$(wc -c < "$wp" | tr -d ' ')"$' bytes)'
    else
      status_line=$'\033[38;5;114mNEW file\033[0m'
    fi
    print -u2 -rn -- $'\033[38;5;244m  → '"$wp"'  '"$status_line"$'\033[0m\n'
    if [[ -s "$la" ]]; then
      local bytes total; bytes="$(wc -c < "$la" | tr -d ' ')"
      total="$(wc -l < "$la" | tr -d ' ')"; [[ -n "$(tail -c1 "$la")" ]] && (( total++ ))
      print -u2 -rn -- $'\033[38;5;240m'
      # `|| [[ -n $_l ]]` so a final line with NO trailing newline still prints —
      # this preview is the safety surface; silently dropping it defeats the point.
      head -3 "$la" | while IFS= read -r _l || [[ -n "$_l" ]]; do
        print -u2 -rn -- "  │ ${_l}"$'\n'
      done
      print -u2 -rn -- "  … (${total} lines, ${bytes} B)"$'\033[0m\n'
    fi
  fi
  # Render $shown RAW (-r), not via prompt expansion (-P): with prompt_subst on
  # (starship sets it), -P would expand a literal "$w"/"$var" inside the command
  # to empty — so you'd approve `remove ""` while the engine actually runs
  # `remove "$w"`. Consent must show exactly what runs. Colours via hard ANSI —
  # cmd_hl's literal \033[…m escapes print correctly through -rn.
  local y=$'\033[38;5;214m' g=$'\033[38;5;240m' n=$'\033[0m'
  print -u2 -rn -- "${y}⚠ run:${n} ${shown}  ${g}[Enter runs · Esc skips]${n} "
  read -k key
  print -u2 ""
  [[ "$key" == $'\n' || "$key" == $'\r' ]]
}

# Drive run → observe → repair for a single starting command.
_dwim_execute_loop() {
  setopt localoptions no_xtrace no_verbose   # keep info=/exit_code=/… assignments off the screen
  local cmd="$1" model="$2" steps=0
  local -a history_json
  while (( steps < 5 )); do
    (( steps++ ))
    local info; info="$(dwim-engine --run "$cmd")"
    local interactive read_only ran exit_code stdout stderr duration cmd_hl
    interactive="$(print -r -- "$info" | _dwim_json interactive)"
    read_only="$(print -r -- "$info" | _dwim_json read_only)"
    ran="$(print -r -- "$info" | _dwim_json ran)"
    exit_code="$(print -r -- "$info" | _dwim_json exit)"
    stdout="$(print -r -- "$info" | _dwim_json stdout)"
    stderr="$(print -r -- "$info" | _dwim_json stderr)"
    # DISPLAY-ONLY syntax-highlighted command (lossless: strips back to $cmd).
    # Never executed — the raw $cmd is what runs below.
    cmd_hl="$(print -r -- "$info" | _dwim_json cmd_hl)"

    # Present interactive tool → hand full-screen to your shell (you Enter).
    # (A MISSING interactive tool comes back exit 127 and falls through to repair.)
    if [[ "$interactive" == "true" && "$exit_code" != "127" ]]; then
      _dwim_load "$cmd"
      return 0
    fi
    # Mutating command not yet run → confirm, then force-run and re-read result.
    if [[ "$interactive" != "true" && "$ran" != "true" ]]; then
      _dwim_confirm "$cmd" "$cmd_hl" || { print -u2 -Pr -- "%F{240}· skipped%f"; return 1 }
      info="$(dwim-engine --run "$cmd" --force)"
      exit_code="$(print -r -- "$info" | _dwim_json exit)"
      stdout="$(print -r -- "$info" | _dwim_json stdout)"
      stderr="$(print -r -- "$info" | _dwim_json stderr)"
    fi

    duration="$(print -r -- "$info" | _dwim_json duration)"   # from the run that actually executed
    _dwim_panel "$cmd" "${stdout:-$stderr}" "$exit_code" "$model" "$duration" "$cmd_hl"
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

# Safety net: if the accept-line widget ever misses an `@intent` (e.g. the very
# first command in a shell, or a plugin re-wrap ordering), the line falls through
# to the shell as an unknown command → `command not found: @find`. Catch it here
# and route to the agent instead of erroring. Chain to any pre-existing handler
# (e.g. nix-index) for genuinely-unknown non-@ commands so we don't clobber it.
if typeset -f command_not_found_handler >/dev/null 2>&1 \
   && [[ -z "$_DWIM_CNF_INSTALLED" ]]; then
  functions[_dwim_orig_cnf_handler]=$functions[command_not_found_handler]
fi
command_not_found_handler() {
  if [[ "$1" == @* ]]; then
    local parsed; parsed="$(_dwim_at_parse "$*")"   # $* keeps the whole @intent
    _dwim_run_action "${parsed#*$'\t'}" "${parsed%%$'\t'*}"
    return $?
  fi
  if typeset -f _dwim_orig_cnf_handler >/dev/null 2>&1; then
    _dwim_orig_cnf_handler "$@"; return $?
  fi
  print -u2 "zsh: command not found: $1"
  return 127
}
typeset -g _DWIM_CNF_INSTALLED=1

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

