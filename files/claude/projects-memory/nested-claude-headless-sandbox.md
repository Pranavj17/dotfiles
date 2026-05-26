---
name: nested-claude-headless-sandbox
description: "Calling `claude -p` from a script on this machine: must sandbox it (--strict-mcp-config, run from neutral dir) or it fails 'Prompt is too long' and triggers project hooks"
metadata: 
  node_type: memory
  type: reference
  originSessionId: cddb8318-22a8-4054-b2e5-ef8f94280319
---

When a shell script calls Claude Code headlessly (`claude -p "<prompt>"`) on this machine, a plain invocation MISBEHAVES because it inherits the full environment:

- **"Prompt is too long" / failure:** the user's MCP config loads ~261k tokens of MCP tool schemas (Amplitude, Asana, Zoho, etc.) into the headless context — that alone blows past smaller models' limits (haiku 200k).
- **Side effects:** run from a project dir, it loads that project's `CLAUDE.md` and fires its SessionStart/SessionEnd hooks (e.g. the memory project's `session-start.sh` boots mix/docker/the Mac-Mini probe). User-level hooks (claude-bot recall/collect in `~/.claude/settings.json`) fire regardless of cwd, so each call can spawn a claude-bot "auto session" memory.

**Fix — sandbox the call:**
```bash
( cd /tmp && printf '%s' "$prompt" \
  | timeout 40 claude -p --strict-mcp-config --model claude-haiku-4-5-20251001 )
```
- `--strict-mcp-config` with no `--mcp-config` ⇒ loads ZERO MCP servers (kills the 261k-token bloat).
- Running from `/tmp` (no `CLAUDE.md`, no project `.claude/`) avoids that project's hooks + context.
- Cold call ≈ 15s; uses the logged-in subscription auth (no `ANTHROPIC_API_KEY` needed — it's unset here).

**Known residual:** user-level claude-bot hooks still fire and may create trivial memories per call; tolerable for low-frequency use (the statusline greeter/slot generators in `~/.claude/statusline/gen-*.sh` use this pattern). Local Ollama was NOT a fallback option — only `all-minilm` (embeddings) is pulled, no text-gen model. See [[dev-env-nix-toolchain]].
