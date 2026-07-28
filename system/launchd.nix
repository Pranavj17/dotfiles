{ pkgs, ... }: {
  # Echo / claude-bot daemon DISABLED (2026-07-28).
  #
  # Root cause: hourly dream cron + Claude.ai Slack MCP + loose tool
  # allowlist (Bash(*), Write(*), etc.) let the background agent DM
  # Slack without a human prompt.
  #
  # Do NOT re-enable launchd.user.agents.claude-bot without:
  #   1. Memory-only tool allowlist (no Bash/Write wildcards, no Slack)
  #   2. Explicit deny of slack_send_message / outbound connectors
  #   3. Dream cron disabled or catchup:false + no notify
  #
  # Previous agent definition removed intentionally so darwin-rebuild /
  # home-manager switch cannot resurrect com.claude-bot.daemon.
}
