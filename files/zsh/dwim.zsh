# dwim — correct the last failed command via a local LLM.
# Records the last command + exit code, then `dwim` asks the engine to fix it
# and loads the suggestion onto your command line (never auto-runs).

typeset -g _DWIM_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last"
typeset -g _DWIM_LAST_CMD=""

_dwim_preexec() {
  case "$1" in
    dwim|dwim\ *) _DWIM_LAST_CMD="" ;;   # never try to fix dwim itself
    *)            _DWIM_LAST_CMD="$1" ;;
  esac
}

_dwim_precmd() {
  local code=$?
  [[ -z "$_DWIM_LAST_CMD" ]] && return
  mkdir -p "${_DWIM_STATE:h}"
  print -r -- "$code"           >  "$_DWIM_STATE"
  print -r -- "$_DWIM_LAST_CMD" >> "$_DWIM_STATE"
  _DWIM_LAST_CMD=""
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _dwim_preexec
# Register our precmd FIRST so $? is the real last exit code, before starship
# (which clobbers $? inside its own precmd) runs.
precmd_functions=(_dwim_precmd ${precmd_functions:#_dwim_precmd})

# Default buffer-load seam; overridden in tests.
_dwim_load() { print -z -- "$1" }

dwim() {
  if [[ ! -f "$_DWIM_STATE" ]]; then
    print -u2 "dwim: nothing to fix"
    return 1
  fi
  local code cmd suggestion
  code="$(sed -n 1p "$_DWIM_STATE")"
  cmd="$(sed -n '2,$p' "$_DWIM_STATE")"
  # Only worth loading the model when the last command actually failed.
  if [[ "$code" == "0" ]]; then
    print -u2 "dwim: last command succeeded — nothing to fix"
    return 1
  fi
  suggestion="$(dwim-engine --cmd "$cmd" --exit "$code")" || {
    print -u2 "dwim: no correction found"
    return 1
  }
  if [[ -z "$suggestion" ]]; then
    print -u2 "dwim: no correction found"
    return 1
  fi
  _dwim_load "$suggestion"
}
