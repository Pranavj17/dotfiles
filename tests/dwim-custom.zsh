#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp/cache" LOG="$tmp/log"
mkdir -p "$tmp/cache/dwim"; : > "$LOG"

# fzf: echo the candidate list it receives to LOG, then select nothing.
fzf() { cat >> "$LOG"; return 1; }
# agent stub: emit one candidate so real _dwim_run_action reaches fzf.
dwim-action() { print $'do it\techo hi'; }

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

# 4-first) sentinel is appended to the picker list — needs the REAL
# _dwim_run_action, so run this BEFORE stubbing the routing targets below.
_DWIM_SESSION_ID=""; _dwim_run_action "list stuff" fast || true
grep -q "__DWIM_CUSTOM__" "$LOG" \
  || { echo "FAIL: '✎ type your own' sentinel not appended to picker"; exit 1 }

# Now stub the routing targets to observe where a typed line goes.
_dwim_execute_loop() { print "EXEC=[$1] model=[$2]" >> "$LOG"; }
_dwim_run_action()   { print "ACTION intent=[$1] tier=[$2]" >> "$LOG"; }

# 1) bare text routes to the execute loop as a command
: > "$LOG"
_dwim_custom_route "git worktree remove x" haiku
grep -q "EXEC=\[git worktree remove x\] model=\[haiku\]" "$LOG" \
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

echo "PASS: dwim custom-entry routing"
