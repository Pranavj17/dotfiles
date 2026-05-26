#!/usr/bin/env bash
# Post-switch verification for Phase 1.
# Each block can fail independently; we collect failures and exit non-zero at the end.
set -u
fail=0
ok()  { printf '  ok  %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

echo "== flake check =="
( cd "$(dirname "$0")/.." && nix flake check --no-build 2>/dev/null ) && ok "nix flake check" || bad "nix flake check"

# More blocks appended in later tasks (shelltest, starship prompt, har-extract, etc.)

echo "== ~/.local/bin scripts =="
for s in har-extract claude-export-split elixir-version-cached; do
  [ -L "$HOME/.local/bin/$s" ] && [ -x "$HOME/.local/bin/$s" ] && ok "$s symlink+exec" || bad "$s symlink+exec"
done

echo "== shelltest (statusline + secret helper) =="
bash "$HOME/.config/shell-tests/run.sh" >/dev/null && ok "shelltest 28/28" || bad "shelltest 28/28"

echo "== starship prompt renders =="
( cd "$HOME" && starship prompt --terminal-width=120 >/dev/null ) && ok "starship prompt" || bad "starship prompt"

echo "== claude config files symlinked =="
for f in settings.json keybindings.json statusline-command.sh statusline/test.sh; do
  [ -L "$HOME/.claude/$f" ] && ok ".claude/$f" || bad ".claude/$f"
done

echo
[ "$fail" -eq 0 ] && echo "✅ smoke PASSED" || echo "❌ smoke FAILED"
exit "$fail"
