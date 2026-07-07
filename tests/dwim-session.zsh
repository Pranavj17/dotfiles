#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"
# Stub dwim-action: record DWIM_RESUME, write a session id to DWIM_SESSION_FILE, emit one cand.
cat > "$tmp/dwim-action" <<'EOF'
#!/usr/bin/env zsh
print "resume=[${DWIM_RESUME}]" >> "$LOG"
print "sess-$(( ++_N ))" > "$DWIM_SESSION_FILE"    # a fresh id each call
print $'do it\techo hi'                            # one candidate on stdout
EOF
chmod +x "$tmp/dwim-action"
export PATH="$tmp:$PATH" LOG="$tmp/log" XDG_CACHE_HOME="$tmp/cache"
# Pre-create the cache dir the stub writes into (the real dwim-action does
# this itself via os.makedirs before writing DWIM_SESSION_FILE; our stub is
# a plain `print >`, so the harness creates it instead).
mkdir -p "$tmp/cache/dwim"
: > "$LOG"; typeset -g _N=0
# fzf: pick nothing so we don't enter the execute loop (we only test session mgmt).
fzf() { return 1; }

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

# 1) first call: fresh (no resume), session captured
# (fzf is stubbed to fail-select, so _dwim_run_action's own return is non-zero
# by design here — guard it like tests/dwim-at.zsh already does, so `set -e`
# doesn't abort the harness before we get to the assertions below.)
_dwim_run_action "what is big" fast || true
grep -q "resume=\[\]" "$LOG" || { echo "FAIL: first call should be fresh"; exit 1 }
[[ -n "$_DWIM_SESSION_ID" ]] || { echo "FAIL: session id not captured"; exit 1 }
first="$_DWIM_SESSION_ID"

# 2) second call: continues (resume = first id)
_dwim_run_action "why the venv" fast || true
grep -q "resume=\[$first\]" "$LOG" || { echo "FAIL: second call should resume first session"; exit 1 }
[[ "$_DWIM_SESSION_TURNS" -ge 1 ]] || { echo "FAIL: turn counter not incremented"; exit 1 }

# 3) 'new ' prefix resets (fresh even though a session exists)
: > "$LOG"
_dwim_run_action "new how do I zip" fast || true
grep -q "resume=\[\]" "$LOG" || { echo "FAIL: 'new' prefix should start fresh"; exit 1 }

# 4) idle expiry: pretend last use was 20 min ago → fresh
_DWIM_SESSION_TS=$(( EPOCHSECONDS - 1200 ))
: > "$LOG"
_dwim_run_action "unrelated q" fast || true
grep -q "resume=\[\]" "$LOG" || { echo "FAIL: idle >15m should start fresh"; exit 1 }

# 5) dwim new clears the session var
dwim new
[[ -z "$_DWIM_SESSION_ID" ]] || { echo "FAIL: 'dwim new' should clear session"; exit 1 }

echo "PASS: dwim session threading"
