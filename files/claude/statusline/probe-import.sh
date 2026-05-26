#!/usr/bin/env bash
# Count context .md files newer than their DB row (i.e. needing `mix import_contexts`).
# Writes the integer to /tmp/.claude-import. Deterministic; cached 60s by the renderer.
# Uses psql directly (fast, no BEAM boot). Filename {name}.md <-> key context.{name}.
set -u
STATE="/tmp/.claude-import"; LOCK="${STATE}.lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

DIR="$HOME/Documents/memory/training/materials/contexts"
[ -d "$DIR" ] || { printf '0' > "$STATE"; exit 0; }
command -v psql >/dev/null 2>&1 || { printf '?' > "$STATE"; exit 0; }

# key (sans "context.") -> updated_at epoch
rows=$(PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d memory_dev -tA -F $'\t' \
  -c "SELECT replace(key,'context.',''), extract(epoch from updated_at)::bigint \
      FROM memories WHERE 'context' = ANY(tags)" 2>/dev/null)
[ -z "$rows" ] && { printf '?' > "$STATE"; exit 0; }

count=0
for f in "$DIR"/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f" .md)
  [ "$base" = "README" ] && continue
  fmt=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)
  db=$(printf '%s\n' "$rows" | awk -F'\t' -v n="$base" '$1==n{print $2; exit}')
  if [ -z "$db" ] || [ "${fmt:-0}" -gt "$db" ]; then count=$((count+1)); fi
done
printf '%s' "$count" > "$STATE"
