---
name: helixa-mcp-prompts
description: "Helixa MCP prompts (welcome + desk shortcuts); MCP prompt args are static, so admin impersonation needs a separate _for variant"
metadata: 
  node_type: memory
  type: project
  originSessionId: 86ccab66-fee9-4f76-a0e6-c6fa0feaa9c5
---

Helixa MCP exposes role-aware `@mcp.prompt()` shortcuts in `helixa_server/server.py` (pure `_*_messages(p)` builder + thin wrapper + `_emit_prompt` audit), advertised in `build_instructions()` PROMPTS block. Live: `welcome`, `daily_brief`, `client_snapshot`, `daily_brief_for`, `client_snapshot_for`.

**Why:** desk shortcuts that fire on the authenticated session identity (whoami/_resolve_principal), no typed identity input.

**How to apply / key constraint:** MCP prompt arguments are STATIC per prompt (declared at registration, same for every caller) — you canNOT show a field to admins only. A declared arg makes Claude Desktop pop an "Enter prompt inputs" dialog for everyone. So the pattern is a SPLIT: base prompt = zero args (runs own book, no dialog); `_for` variant declares `on_behalf_of` so admins are prompted for the target RM. Builder's `_impersonation_target(p, on_behalf_of)` coerces non-admins to self; the tools (resolve_book/resolve_mailbox) re-gate too — defense in depth. Test the input-field contract via `prompt.arguments` on the captured FastMCP `_prompt_manager._prompts`.

**Client cache gotcha (verified 2026-06-09):** a Claude Desktop/Code MCP connector fetches `prompts/list` ONCE at connect and caches it. After deploying a prompt add/rename/signature change, the picker keeps showing the stale list (symptom: only `welcome` visible, new prompts missing) even though the server serves them. Fix = toggle the connector off/on in Manage Connectors, or Cmd+Q + reopen. Don't chase it as a server bug. Also: prod deploy is MANUAL (CI builds image on main but does NOT deploy; run `scripts/deploy-prod-via-nexus.sh`) — helixa web pod is `deploy/helixa` in `nexus` ns on port 8765, MCP path `/mcp/helixa/mcp`. Token-free server check: `kubectl -n nexus exec <pod> -- grep '@mcp.prompt' <site-packages>/customer360/mcp/helixa_server/server.py`.

Shipped main: MR !66 (initial), MR !67 (no-dialog split). Test file `tests/mcp/test_brief_snapshot_prompts.py`; run via [[helixa-test-runner-venv]]. Related: [[helixa-session-role-greeting]] [[helixa-impersonation-on-behalf-of-fix]] [[helixa-project]]
