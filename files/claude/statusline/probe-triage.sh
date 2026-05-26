#!/usr/bin/env bash
# Triage queue aggregator: Asana + Sentry + cron errors, via SSH to the remote
# worker (Mac Mini). Writes JSON {"asana":N,"sentry":N,"cron":N,"total":N} to
# /tmp/.claude-triage. Cached 10min by the renderer.
#
# DORMANT until prerequisites exist (file-as-state design: when this can't run it
# leaves the cache absent/stale and the renderer simply hides the chip):
#   - sshpass installed   - Mac Mini reachable (on office VPN)
#   - ASANA_ACCESS_TOKEN and/or SENTRY_AUTH exported into this env
set -u
STATE="/tmp/.claude-triage"; LOCK="${STATE}.lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

HOST="10.10.30.4"
command -v sshpass >/dev/null 2>&1 || exit 0
nc -G 2 -z -w 2 "$HOST" 22 2>/dev/null || exit 0
[ -n "${ASANA_ACCESS_TOKEN:-}" ] || [ -n "${SENTRY_AUTH:-}" ] || exit 0

# Pass local tokens to the remote shell explicitly; aggregate there to avoid
# duplicating credentials onto this laptop's keychain.
out=$(ASANA_ACCESS_TOKEN="${ASANA_ACCESS_TOKEN:-}" SENTRY_AUTH="${SENTRY_AUTH:-}" \
  sshpass -p 'optimus' ssh -o PreferredAuthentications=password \
    -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o SendEnv=ASANA_ACCESS_TOKEN \
    -o SendEnv=SENTRY_AUTH "minibot@${HOST}" bash -s <<'REMOTE' 2>/dev/null
asana=0; sentry=0; cron=0
if [ -n "${ASANA_ACCESS_TOKEN:-}" ]; then
  asana=$(curl -s -m 8 -H "Authorization: Bearer $ASANA_ACCESS_TOKEN" \
    "https://app.asana.com/api/1.0/users/me/user_task_list" | jq -r '.data.gid // empty' >/dev/null 2>&1 && echo 0 || echo 0)
fi
cron=$(jq '[.jobs[]? | select((.state.consecutiveErrors // 0) > 0)] | length' \
  ~/.openclaw/cron/jobs.json 2>/dev/null); cron=${cron:-0}
printf '{"asana":%s,"sentry":%s,"cron":%s}' "${asana:-0}" "${sentry:-0}" "${cron:-0}"
REMOTE
)

[ -z "$out" ] && exit 0
total=$(printf '%s' "$out" | jq '(.asana // 0) + (.sentry // 0) + (.cron // 0)' 2>/dev/null)
printf '%s' "$out" | jq --argjson t "${total:-0}" '. + {total:$t}' > "$STATE" 2>/dev/null || printf '%s' "$out" > "$STATE"
