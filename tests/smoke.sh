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

echo "== claude config files present =="
for f in keybindings.json statusline-command.sh statusline/test.sh; do
  [ -L "$HOME/.claude/$f" ] && ok ".claude/$f symlink" || bad ".claude/$f symlink"
done
# settings.json is NOT managed by HM — managed manually by ds/cc toggle
[ -f "$HOME/.claude/settings.json" ] && ok ".claude/settings.json present" || bad ".claude/settings.json present"

echo "== claude-bot daemon (must stay off) =="
# Echo was disabled after unsolicited Slack DMs from dream cron (2026-07-28).
# Fail smoke if the agent is running or the launchd job is still loaded.
if launchctl print "gui/$UID/com.claude-bot.daemon" 2>/dev/null | grep -qE 'state\s*=\s*running'; then
  bad "claude-bot launchd RUNNING (should be disabled)"
elif launchctl print "gui/$UID/com.claude-bot.daemon" >/dev/null 2>&1; then
  bad "claude-bot launchd still loaded (should be unloaded)"
elif [ -f "$HOME/Library/LaunchAgents/com.claude-bot.daemon.plist" ]; then
  bad "claude-bot plist still present under LaunchAgents"
else
  ok "claude-bot launchd absent (expected)"
fi


echo
[ "$fail" -eq 0 ] && echo "✅ smoke PASSED" || echo "❌ smoke FAILED"
exit "$fail"
