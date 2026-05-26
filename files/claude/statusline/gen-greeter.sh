#!/usr/bin/env bash
# Session greeter: ONE-line orientation synthesizing cwd + recent memory notes.
# Written once at SessionStart; the renderer fades it after 5 min.
#
# Uses a SANDBOXED `claude -p` (haiku): run from /tmp with --strict-mcp-config so
# it loads NO MCP servers (avoids the ~261k-token tool blowup) and no project
# CLAUDE.md/hooks. Arg $1 = cwd (optional). Fails silent -> chip stays hidden.
set -u
STATE="/tmp/.claude-greeter"; LOCK="${STATE}.lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

command -v claude >/dev/null 2>&1 || exit 0
cwd="${1:-$HOME/Documents/memory}"

mem=""
for rb in "$cwd/.remember/now.md" "$HOME/Documents/memory/.remember/now.md"; do
  [ -f "$rb" ] && { mem=$(tail -n 25 "$rb" 2>/dev/null); break; }
done

prompt="You are a terminal status-line greeter. Output ONE short sentence (max 12 words; no quotes, no emoji, no preamble) orienting the developer on what they were last working on. Directory: ${cwd}. Recent session notes:
${mem}"

resp=$( cd /tmp && printf '%s' "$prompt" \
  | timeout 40 claude -p --strict-mcp-config --model claude-haiku-4-5-20251001 2>/dev/null )
resp=$(printf '%s' "$resp" | tr -d '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//' | cut -c1-80)

[ -n "$resp" ] && printf '%s' "$resp" > "$STATE"
