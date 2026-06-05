#!/usr/bin/env bash
# SessionStart hook — if the helixa MCP is wired up for THIS project, inject a
# directive telling Claude to greet the user with their helixa ROLE on the very
# first reply. Claude Code is the only client with session hooks; Claude Desktop
# and the mobile app rely on helixa's own server `instructions` (best-effort) for
# the same greeting. Stays silent in non-helixa projects so other sessions are
# untouched.
set -euo pipefail

input=$(cat 2>/dev/null || true)
cwd=$(printf '%s' "$input" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("cwd",""))
except Exception:
    print("")' 2>/dev/null || true)
[ -z "$cwd" ] && cwd="$PWD"

# Is helixa connected for this project? Check the per-project MCP config in
# ~/.claude.json plus any project-local MCP files. Exit silently if not.
python3 - "$cwd" <<'PY' 2>/dev/null || exit 0
import json, os, sys
cwd = sys.argv[1]
def hit():
    try:
        d = json.load(open(os.path.expanduser("~/.claude.json")))
        ms = d.get("projects", {}).get(cwd, {}).get("mcpServers", {})
        if any("helixa" in k.lower() for k in ms):
            return True
    except Exception:
        pass
    for rel in (".mcp.json", ".claude/settings.json", ".claude/settings.local.json"):
        p = os.path.join(cwd, rel)
        try:
            if os.path.isfile(p) and "helixa" in open(p).read().lower():
                return True
        except Exception:
            pass
    return False
sys.exit(0 if hit() else 1)
PY

read -r -d '' GREETING <<'TXT' || true
HELIXA SESSION GREETING (do this FIRST, before anything else, even if the user only says "hi" / "hey"): The helixa MCP is connected this session. Immediately call mcp__helixa__whoami (load it via ToolSearch first if it isn't available yet), then open your FIRST reply with a short, warm, best-friend-style greeting that STATES the user's role. admin -> playful "you've got the keys 🫡" energy, naming ADMIN and full-desk/every-book access. RM -> warm "welcome back" plus their book size via mcp__helixa__list_my_clients. Name the role in the first sentence, keep the whole greeting to 1-2 sentences, then ask who/what they want to look at. Do NOT print a formal status line and do NOT list the available tools.
TXT

jq -n --arg info "$GREETING" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $info}}'
