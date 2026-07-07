#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp/cache" LOG="$tmp/log"
mkdir -p "$tmp/cache/dwim"; : > "$LOG"

# agent stub: emit one candidate so real _dwim_run_action reaches fzf.
dwim-action() { print $'do it\techo hi'; }

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

# --- picker query routing (uses the REAL _dwim_run_action) -------------------
# Run these BEFORE stubbing the routing targets. --print-query means fzf's output
# is "<query>\n<selected line>"; we stub fzf to emit each shape.

# 4a) TYPED a command, NO candidate matched, Enter (fzf exit 1) → fzf returns only
#     the query line → the query must be run as a command (via _dwim_execute_loop).
_dwim_execute_loop() { print "EXEC=[$1]" >> "$LOG"; }
fzf() { cat >/dev/null; print -r -- "git worktree remove x"; return 1; }   # query only
: > "$LOG"; _DWIM_SESSION_ID=""; _dwim_run_action "list stuff" fast || true
grep -q "EXEC=\[git worktree remove x\]" "$LOG" \
  || { echo "FAIL: typed non-matching command (Enter) should run via _dwim_custom_route"; exit 1 }

# 4b) SELECTED a candidate (query + selection line, fzf exit 0) → the SELECTED
#     command runs, not the query.
fzf() { cat >/dev/null; printf '%s\n%s\n' "some query" $'do it\techo hi'; return 0; }
: > "$LOG"; _dwim_run_action "list stuff" fast || true
grep -q "EXEC=\[echo hi\]" "$LOG" \
  || { echo "FAIL: a selected candidate should run its command, not the query"; exit 1 }

# 4c) TYPED then Esc/abort (fzf exit 130) → --print-query still prints the query,
#     but the run must be CANCELLED (nothing executed).
fzf() { cat >/dev/null; print -r -- "rm -rf danger"; return 130; }
: > "$LOG"; _dwim_run_action "list stuff" fast || true
grep -q "EXEC=" "$LOG" \
  && { echo "FAIL: Esc after typing must cancel, not run the typed query"; exit 1 }
unset -f fzf

# --- _dwim_custom_route unit checks (decision C) -----------------------------
_dwim_run_action() { print "ACTION intent=[$1] tier=[$2]" >> "$LOG"; }

# 1) bare text routes to the execute loop as a command
: > "$LOG"
_dwim_custom_route "git worktree remove x" haiku
grep -q "EXEC=\[git worktree remove x\]" "$LOG" \
  || { echo "FAIL: bare text should run as a command"; exit 1 }

# 2) @-prefixed text routes to a new agent turn (fast tier)
: > "$LOG"
_dwim_custom_route "@also the tax ones" haiku
grep -q "ACTION intent=\[also the tax ones\] tier=\[fast\]" "$LOG" \
  || { echo "FAIL: @text should re-invoke the agent (fast)"; exit 1 }

# 3) @@-prefixed text routes to the deep tier
: > "$LOG"
_dwim_custom_route "@@hard question" haiku
grep -q "ACTION intent=\[hard question\] tier=\[deep\]" "$LOG" \
  || { echo "FAIL: @@text should re-invoke the agent (deep)"; exit 1 }

echo "PASS: dwim picker query routing"
