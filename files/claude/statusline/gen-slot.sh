#!/usr/bin/env bash
# Adaptive insight slot: ONE short line surfacing only what the deterministic chips
# CANNOT — cross-signal synthesis, a time pattern, an absence, or soft judgment.
# Sandboxed `claude -p` (haiku). Opportunistically forked by the renderer ~every
# 45 min. If nothing useful, writes an empty file so we don't refetch until TTL.
set -u
STATE="/tmp/.claude-slot"; LOCK="${STATE}.lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

command -v claude >/dev/null 2>&1 || exit 0

mini=$(cat /tmp/.claude-mini 2>/dev/null)
imp=$(cat /tmp/.claude-import 2>/dev/null)
hour=$(date +%H)
mem=""
for rb in "$HOME/Documents/memory/.remember/now.md"; do
  [ -f "$rb" ] && mem=$(tail -n 20 "$rb" 2>/dev/null)
done

prompt="You write ONE terminal insight (max 10 words; no quotes, no emoji). Surface ONLY what raw status chips cannot: a time-of-day pattern, the ABSENCE of an expected event, or soft judgment. Do NOT restate counts. If nothing genuinely useful, reply with exactly: -
Signals: hour=${hour}, macmini=${mini:-unknown}, contexts_needing_import=${imp:-0}
Recent session notes:
${mem}"

resp=$( cd /tmp && printf '%s' "$prompt" \
  | timeout 40 claude -p --strict-mcp-config --model claude-haiku-4-5-20251001 2>/dev/null )
resp=$(printf '%s' "$resp" | tr -d '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//' | cut -c1-60)
[ "$resp" = "-" ] && resp=""

# Always (re)write so the file mtime advances and the 45-min TTL resets either way.
printf '%s' "$resp" > "$STATE"
