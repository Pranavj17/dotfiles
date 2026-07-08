#!/usr/bin/env zsh
set -e
tmp="$(mktemp -d)"
# Stub dwim-engine: record the args it was called with, print a fake listing.
cat > "$tmp/dwim-engine" <<'EOF'
#!/usr/bin/env zsh
print -r -- "ENGINE args=[$*]" >> "$LOG"
print -r -- "git"
print -r -- "k8s"
print -r -- "sql"
EOF
chmod +x "$tmp/dwim-engine"
export PATH="$tmp:$PATH" LOG="$tmp/log" XDG_CACHE_HOME="$tmp/cache"
mkdir -p "$tmp/cache/dwim"; : > "$LOG"

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true
# Unregister preexec hooks so they don't fire on this script's own lines.
autoload -Uz add-zsh-hook
add-zsh-hook -d preexec _dwim_preexec 2>/dev/null || true
add-zsh-hook -d preexec _dwim_clear_replay 2>/dev/null || true

# `dwim personas` must invoke `dwim-engine --personas`.
out="$(dwim personas)"
grep -q "ENGINE args=\[--personas\]" "$LOG" \
  || { echo "FAIL: 'dwim personas' should call dwim-engine --personas"; exit 1 }
print -r -- "$out" | grep -q "^git$" \
  || { echo "FAIL: 'dwim personas' should list personas from the engine"; exit 1 }

# `dwim help` should mention the personas command + the @<persona> syntax.
dwim help | grep -q "dwim personas" \
  || { echo "FAIL: 'dwim help' should mention 'dwim personas'"; exit 1 }
dwim help | grep -q "@<persona>" \
  || { echo "FAIL: 'dwim help' should mention the @<persona> syntax"; exit 1 }

echo "PASS: dwim personas (dispatch + help)"
