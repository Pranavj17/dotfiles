#!/usr/bin/env zsh
set -e
tmp="$(mktemp -d)"; export XDG_CACHE_HOME="$tmp/cache"; mkdir -p "$tmp/cache/dwim"
source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

ok="$(_dwim_panel "echo hi" "hi" 0 sonnet 2>&1)"
print -r -- "$ok" | grep -q "✓" || { echo "FAIL: success should show ✓"; exit 1 }
if print -r -- "$ok" | grep -q "✓ 0"; then echo "FAIL: success must NOT show '✓ 0'"; exit 1; fi

bad="$(_dwim_panel "false" "" 1 sonnet 2>&1)"
print -r -- "$bad" | grep -q "✗ 1" || { echo "FAIL: failure should show ✗ 1"; exit 1 }

# Consent integrity: with prompt_subst ON (starship sets it), the panel header
# must show a literal "$w" in the command, not expand it to "" — otherwise the
# displayed command differs from what actually runs.
setopt prompt_subst
subst="$(_dwim_panel 'git worktree remove --force "$w"' "" 0 haiku 2>&1)"
print -r -- "$subst" | grep -q 'remove --force "$w"' \
  || { echo 'FAIL: panel must show literal "$w", not expand it under prompt_subst'; exit 1 }

# Same for the confirm prompt. The prompt text is emitted BEFORE `read -k`, so we
# capture it even though `read -k` errors in this non-tty test (|| true keeps
# set -e from tripping on that — irrelevant to the display assertion).
confirm="$(_dwim_confirm 'git rm "$w"' 2>&1 || true)"
print -r -- "$confirm" | grep -q 'git rm "$w"' \
  || { echo 'FAIL: confirm prompt must show literal "$w" under prompt_subst'; exit 1 }

echo "PASS: dwim panel footer"
