#!/usr/bin/env bash
# `make switch` transcript. The password prompt happens before the log
# starts, so sudo's prompt is not mixed into the formatted output.
set -uo pipefail

host="${DARWIN_HOST:-SB-111}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

printf '\nswitch  .#%s\n' "$host"
printf '  nix-darwin and home-manager, then smoke\n'

sudo -v || exit 1

sudo nix run nix-darwin -- switch --flake ".#${host}" 2>&1 \
  | /usr/bin/python3 "$root/scripts/switch-format.py"
status=${PIPESTATUS[0]}
if [[ "$status" -ne 0 ]]; then
  printf '\nswitch failed  nix-darwin exit %s\n' "$status"
  exit "$status"
fi

printf '\n'
bash tests/smoke.sh
status=$?
if [[ "$status" -ne 0 ]]; then
  printf '\nswitch failed  smoke exit %s\n' "$status"
  exit "$status"
fi

printf '\nswitch ok\n'
