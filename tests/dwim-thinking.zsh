#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp/cache"
mkdir -p "$tmp/cache/dwim"

# The ENGINE now owns last_thinking (Python _StreamUI writes the full trace);
# zsh no longer tees stderr into it. Stub dwim-action to behave like the real
# engine: draw a live spinner to the terminal (stderr) AND write last_thinking
# itself, then emit one candidate on stdout.
cat > "$tmp/dwim-action" <<'EOF'
#!/usr/bin/env zsh
print -u2 "⠋ dwim · haiku · du -ah"                 # live spinner → terminal (stderr)
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/dwim"
print -r -- "  › du -ah . | sort -rh | head" \
  > "${XDG_CACHE_HOME:-$HOME/.cache}/dwim/last_thinking"   # engine owns the trace file
print $'do it\techo hi'                             # one candidate on stdout
EOF
chmod +x "$tmp/dwim-action"; export PATH="$tmp:$PATH"
fzf() { return 1; }   # don't enter the loop

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

_DWIM_SESSION_ID=""; _dwim_run_action "what is big" fast || true
thinkfile="$tmp/cache/dwim/last_thinking"
grep -q "du -ah" "$thinkfile" \
  || { echo "FAIL: engine's last_thinking trace missing"; exit 1 }
# zsh must NOT tee the live spinner line into the trace — the engine owns it.
grep -q "⠋" "$thinkfile" \
  && { echo "FAIL: zsh tee'd the spinner into last_thinking (should be engine-owned)"; exit 1 }
dwim thinking | grep -q "du -ah" \
  || { echo "FAIL: 'dwim thinking' should reprint the engine's log"; exit 1 }
echo "PASS: dwim thinking log"
