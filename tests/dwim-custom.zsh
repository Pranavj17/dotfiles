#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp/cache" LOG="$tmp/log"
mkdir -p "$tmp/cache/dwim"; : > "$LOG"

# agent stub: emit one candidate so real _dwim_run_action reaches fzf.
dwim-action() { print $'do it\techo hi'; }

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

# --- picker plumbing: REAL _dwim_run_action, stubbed routing targets ---------
# --print-query means fzf's output is "<query>\n<selected line>"; we stub fzf to
# emit each shape and stub the routing callees so there's no recursion. Save the
# real _dwim_custom_route first so section B can restore + exercise it.
functions[_dwim_custom_route_real]=$functions[_dwim_custom_route]
_dwim_custom_route() { print "ROUTE=[$1]" >> "$LOG"; }
_dwim_execute_loop() { print "EXEC=[$1]" >> "$LOG"; }

# A1) TYPED text, NO candidate matched, Enter (fzf exit 1) → the query is handed
#     to _dwim_custom_route (which decides ask-vs-run).
fzf() { cat >/dev/null; print -r -- "show me"; return 1; }   # query only
: > "$LOG"; _DWIM_SESSION_ID=""; _dwim_run_action "list stuff" fast || true
grep -q "ROUTE=\[show me\]" "$LOG" \
  || { echo "FAIL: typed non-matching query should reach _dwim_custom_route"; exit 1 }

# A2) SELECTED a candidate (query + selection line, fzf exit 0) → the SELECTED
#     command runs, not the query, and it does NOT go through custom_route.
fzf() { cat >/dev/null; printf '%s\n%s\n' "some query" $'do it\techo hi'; return 0; }
: > "$LOG"; _dwim_run_action "list stuff" fast || true
grep -q "EXEC=\[echo hi\]" "$LOG" \
  || { echo "FAIL: a selected candidate should run its command, not the query"; exit 1 }
grep -q "ROUTE=" "$LOG" \
  && { echo "FAIL: a selection must not go through custom_route"; exit 1 }

# A3) TYPED then Esc/abort (fzf exit 130) → nothing routed or run.
fzf() { cat >/dev/null; print -r -- "rm -rf danger"; return 130; }
: > "$LOG"; _dwim_run_action "list stuff" fast || true
grep -qE "EXEC=|ROUTE=" "$LOG" \
  && { echo "FAIL: Esc after typing must cancel, not route/run the typed query"; exit 1 }
unset -f fzf

# --- _dwim_custom_route routing decisions ------------------------------------
# Restore the REAL _dwim_custom_route; stub the agent + run targets it calls.
functions[_dwim_custom_route]=$functions[_dwim_custom_route_real]
_dwim_run_action() { print "ACTION intent=[$1] tier=[$2]" >> "$LOG"; }

# 1) bare prose → ask the agent (fast), NOT the shell (the "show me" bug fix)
: > "$LOG"
_dwim_custom_route "show me the worktrees" haiku
grep -q "ACTION intent=\[show me the worktrees\] tier=\[fast\]" "$LOG" \
  || { echo "FAIL: bare text should ask the agent (fast)"; exit 1 }
grep -q "EXEC=" "$LOG" \
  && { echo "FAIL: bare prose must NOT be run through /bin/sh"; exit 1 }

# 2) !command → run that exact command via the execute loop (! and a space stripped)
: > "$LOG"
_dwim_custom_route '!git worktree prune' haiku
grep -q "EXEC=\[git worktree prune\]" "$LOG" \
  || { echo "FAIL: !cmd should run the exact command"; exit 1 }

# 3) @-prefixed text routes to a new agent turn (fast tier)
: > "$LOG"
_dwim_custom_route "@also the tax ones" haiku
grep -q "ACTION intent=\[also the tax ones\] tier=\[fast\]" "$LOG" \
  || { echo "FAIL: @text should re-invoke the agent (fast)"; exit 1 }

# 4) @@-prefixed text routes to the deep tier
: > "$LOG"
_dwim_custom_route "@@hard question" haiku
grep -q "ACTION intent=\[hard question\] tier=\[deep\]" "$LOG" \
  || { echo "FAIL: @@text should re-invoke the agent (deep)"; exit 1 }

echo "PASS: dwim picker query routing"
