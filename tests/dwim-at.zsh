#!/usr/bin/env zsh
set -e
# Stub dwim-action to record the DWIM_TIER it was invoked with.
tmp="$(mktemp -d)"
cat > "$tmp/dwim-action" <<'EOF'
#!/usr/bin/env zsh
print "tier=${DWIM_TIER:-fast} intent=$1" >> "$TIER_LOG"
EOF
chmod +x "$tmp/dwim-action"
export PATH="$tmp:$PATH"
export TIER_LOG="$tmp/log"
: > "$TIER_LOG"

# Source only the functions we need by defining minimal ZLE-free shims.
# _dwim_run_action must set DWIM_TIER from its 2nd arg.
source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

# Call the routing helper directly (no ZLE): fast then deep.
fzf() { cat >/dev/null; return 1; }   # no selection; we only care about the tier log
_dwim_run_action "what is big" fast || true
_dwim_run_action "why is x big" deep || true

grep -q "tier=fast intent=what is big" "$TIER_LOG" || { echo "FAIL: fast tier"; exit 1; }
grep -q "tier=deep intent=why is x big" "$TIER_LOG" || { echo "FAIL: deep tier"; exit 1; }
echo "PASS: dwim-at tier routing"

# _dwim_at_parse "<buffer>" -> prints "<tier>\t<intent>"
[[ "$(_dwim_at_parse '@@why big')" == $'deep\twhy big' ]] || { echo "FAIL: @@ parse"; exit 1; }
[[ "$(_dwim_at_parse '@what big')" == $'fast\twhat big' ]] || { echo "FAIL: @ parse"; exit 1; }
echo "PASS: dwim-at buffer parse"
