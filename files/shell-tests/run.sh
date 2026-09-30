#!/usr/bin/env bash
# Run all shell-tooling regression tests. Exit non-zero if any suite fails.
# Wired to the `shelltest` alias in ~/.zshrc.
set -u
rc=0
echo "### secret helper ###"
bash "$(dirname "$0")/secret.sh" || rc=1
echo
[ "$rc" -eq 0 ] && echo "✅ ALL SHELL TESTS PASSED" || echo "❌ SOME TESTS FAILED"
exit "$rc"
