#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp/cache" LOG="$tmp/log"
mkdir -p "$tmp/cache/dwim"; : > "$LOG"

# Stub dwim-action to simulate a Ctrl-C'd run: exit 130, no output.
cat > "$tmp/dwim-action" <<'EOF'
#!/usr/bin/env zsh
exit 130
EOF
chmod +x "$tmp/dwim-action"; export PATH="$tmp:$PATH"
# fzf/panel must NOT be reached on cancel.
fzf() { print "FZF-CALLED" >> "$LOG"; return 1; }

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true
_dwim_panel() { print "PANEL-CALLED" >> "$LOG"; }

# a live thread exists (turn 2); cancel must leave it untouched
typeset -g _DWIM_SESSION_ID="sess-live" _DWIM_SESSION_TURNS=2 _DWIM_SESSION_TS=$EPOCHSECONDS

msg="$(_dwim_run_action "delete everything" fast 2>&1 || true)"
print -r -- "$msg" | grep -q "cancelled" \
  || { echo "FAIL: cancel should print '⊘ cancelled'"; exit 1 }
[[ "$_DWIM_SESSION_TURNS" == 2 ]] \
  || { echo "FAIL: cancel must not advance the thread ($_DWIM_SESSION_TURNS)"; exit 1 }
[[ "$_DWIM_SESSION_ID" == "sess-live" ]] \
  || { echo "FAIL: cancel must not clobber the session id"; exit 1 }
grep -q "FZF-CALLED\|PANEL-CALLED" "$LOG" \
  && { echo "FAIL: cancel must not reach picker/panel"; exit 1 }
echo "PASS: dwim cancel"
