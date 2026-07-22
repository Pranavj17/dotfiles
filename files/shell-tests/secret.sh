#!/usr/bin/env bash
# Test the `secret` Keychain helper from ~/.zshrc.
# Extracts just the secret() function and sources it (avoids running all of .zshrc),
# then exercises set/get/rm with a throwaway Keychain entry under a test account.
set -u
pass=0; fail=0
ok(){ printf '  ok  %s\n' "$1"; pass=$((pass+1)); }
bad(){ printf 'FAIL  %s\n' "$1"; fail=$((fail+1)); }

fn=$(awk '/^secret\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$HOME/.zshrc")
[ -z "$fn" ] && fn=$(awk '/^secret\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$HOME/dotfiles/files/zsh/functions.zsh")
[ -n "$fn" ] || { echo "FAIL: could not extract secret() from ~/.zshrc or ~/dotfiles/files/zsh/functions.zsh"; exit 1; }
eval "$fn"

export SECRET_ACCOUNT="shelltest-$$@example.com"
NAME="_shelltest_secret_$$"
cleanup(){ secret rm "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

secret set "$NAME" "hunter2" >/dev/null
[ "$(secret get "$NAME" 2>/dev/null)" = "hunter2" ] && ok "set/get roundtrip" || bad "set/get roundtrip"

secret set "$NAME" "newpass" >/dev/null
[ "$(secret get "$NAME" 2>/dev/null)" = "newpass" ] && ok "set updates (-U)" || bad "set update"

secret rm "$NAME" >/dev/null 2>&1
if secret get "$NAME" >/dev/null 2>&1; then bad "rm deletes (still present)"; else ok "rm deletes"; fi

if secret set >/dev/null 2>&1; then bad "set without name errors"; else ok "set without name errors"; fi
if secret get _nope_$$ >/dev/null 2>&1; then bad "get missing returns nonzero"; else ok "get missing returns nonzero"; fi

echo
echo "secret: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
