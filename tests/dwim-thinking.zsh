#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp/cache"
mkdir -p "$tmp/cache/dwim"

# Stub dwim-action: stream a grey tool-call to stderr, emit one candidate, exit 0.
cat > "$tmp/dwim-action" <<'EOF'
#!/usr/bin/env zsh
print -u2 "  › du -ah . | sort -rh | head"
print $'do it\techo hi'
EOF
chmod +x "$tmp/dwim-action"; export PATH="$tmp:$PATH"
fzf() { return 1; }   # don't enter the loop

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

_DWIM_SESSION_ID=""; _dwim_run_action "what is big" fast || true
sleep 0.2   # let the async tee flush
thinkfile="$tmp/cache/dwim/last_thinking"
grep -q "du -ah" "$thinkfile" \
  || { echo "FAIL: stderr not tee'd to last_thinking"; exit 1 }
dwim thinking | grep -q "du -ah" \
  || { echo "FAIL: 'dwim thinking' should reprint the log"; exit 1 }
echo "PASS: dwim thinking log"
