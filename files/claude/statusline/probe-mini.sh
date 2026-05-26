#!/usr/bin/env bash
# Mac Mini reachability canary (VPN probe). Writes "up"/"down" to /tmp/.claude-mini.
# Backgrounded by the statusline renderer when the cached value is stale (>30s).
set -u
STATE="/tmp/.claude-mini"; LOCK="${STATE}.lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

HOST="10.10.30.4"
# -G 2 bounds the TCP connect (BSD nc's -w does NOT cap connect; see session-start fix)
if nc -G 2 -z -w 2 "$HOST" 22 2>/dev/null; then
  printf 'up' > "$STATE"
else
  printf 'down' > "$STATE"
fi
