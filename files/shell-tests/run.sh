#!/usr/bin/env bash
# Run all shell-tooling regression tests. Exit non-zero if any suite fails.
# Wired to the `shelltest` alias in ~/.zshrc.
set -u
rc=0
echo "### statusline ###"
bash "$HOME/.claude/statusline/test.sh" || rc=1
echo
echo "### secret helper ###"
bash "$HOME/.config/shell-tests/secret.sh" || rc=1
echo
[ "$rc" -eq 0 ] && echo "✅ ALL SHELL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
exit "$rc"
