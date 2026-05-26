---
name: claude-bot-plugin-bun
description: "claude-bot Claude Code plugin needs bun (its MCP server is `bun run server.ts`); install bun via Nix + bun install in plugin dir, else tools never register."
metadata: 
  node_type: memory
  type: reference
  originSessionId: b7ea1ff6-e246-4cb9-96e2-d1b89ab57b3d
---

The `claude-bot` Claude Code plugin (claude-community marketplace) runs a persistent daemon + memory graph. Its MCP server is defined in the plugin's `.mcp.json` as `command: bun, args: [run, server.ts]`.

**Gotcha:** it requires **`bun`**, which wasn't installed on this machine — so the MCP server failed to start and none of its tools (`setup`, `status`, `message_bot`, `remember`, `recall`, `cron_*`, …) ever registered. Symptom: ToolSearch can't find the claude-bot tools after `/plugin install` + `/reload-plugins`.

**Fix (all-Nix friendly):**
1. `nix profile add nixpkgs#bun`
2. `cd ~/.claude/plugins/cache/claude-community/claude-bot/<ver>/ && bun install` (pulls @anthropic-ai/claude-agent-sdk + @modelcontextprotocol/sdk).
3. `/reload-plugins` (or restart Claude Code) so the server re-spawns with bun on PATH. The `memory` alias launches claude from the Nix-aware login shell, so its PATH already has `~/.nix-profile/bin`.

**Daemon facts:** `setup` writes a launchd plist `~/Library/LaunchAgents/com.claude-bot.daemon.plist` (RunAtLoad + KeepAlive) and `launchctl load`s it. The plist bakes an absolute `bunPath` (`Bun.which`) and a `PATH` built by merging the setup process's PATH with essentials (`/usr/bin`, `/opt/homebrew/bin`, `~/.bun/bin`, …). On this box: `claude`=`/opt/homebrew/bin/claude`, `bun`/`node`=`~/.nix-profile/bin` — so setup must run from a shell whose PATH has BOTH (Nix + Homebrew) or the daemon can't spawn `claude` sessions. Bot home is `~/.claude-bot/` (CLAUDE.md = personality "Echo"; setup preserves a pre-written CLAUDE.md). Related: [[dev-env-nix-toolchain]], [[nix-npx-broken-prefix]].
