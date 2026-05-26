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

echo
[ "$fail" -eq 0 ] && echo "✅ smoke PASSED" || echo "❌ smoke FAILED"
exit "$fail"
