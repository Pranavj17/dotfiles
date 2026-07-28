# Echo / Slack hardening (2026-07-28)

## Incident
`com.claude-bot.daemon` hourly `dream` cron invoked Claude agent SDK; session
called `mcp__claude_ai_Slack__slack_send_message` to user DM without a human prompt.

## Fixes applied
1. Removed HM `launchd.user.agents.claude-bot` (`system/launchd.nix`).
2. Smoke test asserts daemon is **absent** (`tests/smoke.sh`).
3. Tightened `~/.claude-bot/.claude/settings.local.json` (memory/read only; deny Bash/Write/Slack/cron mutate).
4. Disabled Grok Slack MCP; `permission_mode = "default"`.
5. Stripped API keys from `com.claude.model-proxy` LaunchAgent env.

## You should still
- **Rotate** any Anthropic/OpenRouter keys that lived in the old plist (they may be in shell history/logs).
- After `darwin-rebuild` / `home-manager switch`, re-run `tests/smoke.sh` and confirm claude-bot stays off.
- Disconnect Claude.ai Slack (and unused write connectors) in claude.ai settings if you want defense in depth.
- Do not re-enable Echo without a memory-only allowlist.

## Not automated
- Claude.ai connector revocation (web UI).
- Full key rotation at provider consoles.
