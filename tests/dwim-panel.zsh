#!/usr/bin/env zsh
set -e
tmp="$(mktemp -d)"; export XDG_CACHE_HOME="$tmp/cache"; mkdir -p "$tmp/cache/dwim"
source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

ok="$(_dwim_panel "echo hi" "hi" 0 sonnet 2>&1)"
print -r -- "$ok" | grep -q "✓" || { echo "FAIL: success should show ✓"; exit 1 }
if print -r -- "$ok" | grep -q "✓ 0"; then echo "FAIL: success must NOT show '✓ 0'"; exit 1; fi

bad="$(_dwim_panel "false" "" 1 sonnet 2>&1)"
print -r -- "$bad" | grep -q "✗ 1" || { echo "FAIL: failure should show ✗ 1"; exit 1 }

echo "PASS: dwim panel footer"
