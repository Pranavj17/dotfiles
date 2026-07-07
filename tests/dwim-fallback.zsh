#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"; export XDG_CACHE_HOME="$tmp/cache" LOG="$tmp/log"
mkdir -p "$tmp/cache/dwim"; : > "$LOG"

# Clean slate: no pre-existing not-found handler (so we test dwim's own).
unfunction command_not_found_handler 2>/dev/null || true
unfunction _dwim_orig_cnf_handler 2>/dev/null || true

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true
_dwim_run_action() { print "ACTION intent=[$1] tier=[$2]" >> "$LOG"; }
# Unregister the preexec hooks: they'd otherwise re-fire _dwim_preexec on this
# script's OWN lines and clobber _DWIM_LAST_CMD between our direct unit calls.
autoload -Uz add-zsh-hook
add-zsh-hook -d preexec _dwim_preexec 2>/dev/null || true
add-zsh-hook -d preexec _dwim_clear_replay 2>/dev/null || true

# --- B2: command_not_found_handler routes @ to the agent -----------------------
# @intent that slipped past the accept widget must run the agent, not error.
: > "$LOG"
command_not_found_handler @find big /tmp files
grep -q "ACTION intent=\[find big /tmp files\] tier=\[fast\]" "$LOG" \
  || { echo "FAIL: @intent should route to the agent (fast)"; exit 1 }

: > "$LOG"
command_not_found_handler @@hard question
grep -q "ACTION intent=\[hard question\] tier=\[deep\]" "$LOG" \
  || { echo "FAIL: @@intent should route to the agent (deep)"; exit 1 }

# A genuinely-unknown non-@ command still reports 'command not found' + exit 127.
# (set +e around the capture: the handler intentionally returns 127, which would
# otherwise trip set -e before we read $?.)
: > "$LOG"
set +e; err="$(command_not_found_handler notarealcmd foo 2>&1)"; rc=$?; set -e
[[ "$rc" == 127 ]] || { echo "FAIL: non-@ unknown command must return 127 (got $rc)"; exit 1 }
print -r -- "$err" | grep -q "command not found: notarealcmd" \
  || { echo "FAIL: non-@ unknown command must print the standard message"; exit 1 }
grep -q "ACTION" "$LOG" \
  && { echo "FAIL: a non-@ command must NOT invoke the agent"; exit 1 }

# --- B3: the corrector never treats an @intent as a fixable typo ---------------
_DWIM_LAST_CMD="sentinel"; _dwim_preexec "@find big files"
[[ -z "$_DWIM_LAST_CMD" ]] || { echo "FAIL: @intent must not be recorded as last cmd"; exit 1 }
_dwim_preexec "ls -la"
[[ "$_DWIM_LAST_CMD" == "ls -la" ]] || { echo "FAIL: a real command should be recorded"; exit 1 }
_dwim_preexec "dwim status"
[[ -z "$_DWIM_LAST_CMD" ]] || { echo "FAIL: dwim itself must not be recorded"; exit 1 }

echo "PASS: dwim @ fallbacks (command-not-found + corrector skip)"
