# Put Homebrew binaries ahead of system ones (git, jq, etc.)
export PATH="/opt/homebrew/bin:$PATH"

# Personal scripts (e.g. har-extract)
export PATH="$HOME/.local/bin:$PATH"

# bun's global bin (where `bun install -g <pkg>` puts binaries — e.g. claude)
export PATH="$HOME/.bun/bin:$PATH"

# nanosandbox — lightweight VM sandboxes for code execution
export PATH="$HOME/.nanosandbox/bin:$PATH"

# Run all shell-tooling regression tests (statusline + secret helper)
alias shelltest='bash ~/.config/shell-tests/run.sh'

# autojump — `j <partial-dir-name>` jumps to frequently-used directories
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

# `memory` — jump to the memory project and launch Claude Code (skips permission prompts)
alias memory='cd /Users/pranav.j/Documents/memory && claude --dangerously-skip-permissions'

# `r-vpn` — connect/disconnect the DevOps SSL VPN via Tunnelblick. Usage: r-vpn [up|down|status]
alias r-vpn='~/.vpn_connect'

# `kali` — drop into the Kali Rolling container on Colima (ARM64 native).
# Container baked from kali:tools image with top10 pentest metapackage + NET_RAW cap.
# Persistent workspace mounted at /work from ~/Documents/kali-work.
# Usage:
#   kali                    # bash shell in container
#   kali nmap scanme.nmap.org
#   kali tmux a -t lab      # resume tmux inside
#   docker stop kali        # pause (saves CPU/RAM)
#   docker rm kali && kali  # nuke + recreate from image (recreates container, image is immutable)
kali() {
  if ! docker ps --filter "name=^/kali$" --format '{{.Names}}' | grep -q '^kali$'; then
    if docker ps -a --filter "name=^/kali$" --format '{{.Names}}' | grep -q '^kali$'; then
      docker start kali >/dev/null
    else
      docker run -d --name kali --hostname kali \
        --cap-add NET_RAW --cap-add NET_ADMIN \
        -v "$HOME/Documents/kali-work:/work" -w /work \
        --restart unless-stopped \
        kali:tools sleep infinity >/dev/null
    fi
  fi
  docker exec -it kali "${@:-bash}"
}

# ── secret — universal macOS Keychain helper (keeps secrets out of dotfiles) ──
# Secrets live in the login Keychain (encrypted by macOS), fetched on demand.
#   secret set <name> [value]   # value prompted (hidden) if omitted; -U updates/rotates
#   secret get <name>           # prints the secret — use inside $(secret get NAME)
#   secret rm  <name>
# Account defaults to $SECRET_ACCOUNT (your email).
export SECRET_ACCOUNT="pranav.j@scripbox.com"
secret() {
  local acct="${SECRET_ACCOUNT:-$USER}"
  case "${1:-}" in
    set) local n="${2:-}" v="${3:-}"
         [ -z "$n" ] && { echo "usage: secret set <name> [value]" >&2; return 1; }
         [ -z "$v" ] && { printf 'Value for %s: ' "$n"; read -rs v; echo; }
         security add-generic-password -a "$acct" -s "$n" -w "$v" -U && echo "stored: $n" ;;
    get) local n="${2:-}"; [ -z "$n" ] && { echo "usage: secret get <name>" >&2; return 1; }
         security find-generic-password -s "$n" -a "$acct" -w 2>/dev/null \
           || { echo "secret: no Keychain entry '$n' for $acct" >&2; return 1; } ;;
    rm)  local n="${2:-}"; [ -z "$n" ] && { echo "usage: secret rm <name>" >&2; return 1; }
         security delete-generic-password -s "$n" -a "$acct" ;;
    *)   echo "usage: secret {set|get|rm} <name> [value]" >&2; return 1 ;;
  esac
}

# Graylog MCP (mcp-server-graylog plugin) — token from Keychain, not plaintext.
# Rotate with `rotate_graylog` (defined below). Store the new token: secret set GRAYLOG_API_TOKEN
export GRAYLOG_BASE_URL="https://graylog.scripbox.net"
export GRAYLOG_USER="pranav.j@scripbox.com"
export GRAYLOG_API_TOKEN="$(secret get GRAYLOG_API_TOKEN 2>/dev/null)"

# NVIDIA build.nvidia.com / NIM — image-gen + LLM endpoints. Key in Keychain.
# Rotate at build.nvidia.com → `secret set NVIDIA_API_KEY <new>`.
export NVIDIA_API_KEY="$(secret get NVIDIA_API_KEY 2>/dev/null)"

# Tailscale API — used by scripts hitting the Tailscale REST API (machine list,
# auth-key minting, ACL push, etc.). Key in Keychain. Rotate at
# https://login.tailscale.com/admin/settings/keys → `secret set TAILSCALE_API_KEY <new>`.
export TAILSCALE_API_KEY="$(secret get TAILSCALE_API_KEY 2>/dev/null)"

# ── Metabase (credentials in macOS Keychain — NOT plaintext) ────────────────
# The password lives in the login Keychain, encrypted by macOS. To rotate it:
#   security add-generic-password -a "$METABASE_USER" -s scripbox-metabase -w '<new-pw>' -U
export METABASE_URL="https://metabase.scripbox.net"
export METABASE_USER="pranav.j@scripbox.com"

# Print the Metabase password from Keychain on demand (never exported globally)
metabase_password() {
  security find-generic-password -s scripbox-metabase -a "$METABASE_USER" -w 2>/dev/null \
    || { echo "metabase_password: no Keychain entry for $METABASE_USER" >&2; return 1; }
}

# Open an authenticated Metabase session; echoes the session token
metabase_token() {
  local pw; pw="$(metabase_password)" || return 1
  jq -nc --arg u "$METABASE_USER" --arg p "$pw" '{username:$u,password:$p}' \
    | curl -s -X POST "$METABASE_URL/api/session" -H 'Content-Type: application/json' --data @- \
    | jq -r '.id // empty'
}

# metabase_lead_id <email> — list lead_id(s) auth_production has for a customer email
#   columns: lead_id  email  email_verified  inserted_at   (verified first, oldest first)
metabase_lead_id() {
  local email="$1"
  [ -z "$email" ] && { echo "usage: metabase_lead_id <email>" >&2; return 1; }
  local token; token="$(metabase_token)"
  [ -z "$token" ] && { echo "metabase_lead_id: auth failed (rotated password? refresh Keychain with -U)" >&2; return 1; }
  jq -nc --arg e "$email" '{database:13,type:"native",native:{query:"SELECT lead_id, email, email_verified, inserted_at FROM accounts_user WHERE lower(email)=lower({{email}}) ORDER BY email_verified DESC, inserted_at","template-tags":{email:{name:"email","display-name":"email",type:"text"}}},parameters:[{type:"category",target:["variable",["template-tag","email"]],value:$e}]}' \
    | curl -s -X POST "$METABASE_URL/api/dataset" -H "X-Metabase-Session: $token" -H 'Content-Type: application/json' --data @- \
    | jq -r '(.data.rows[]? | @tsv) // .error'
}

# ── secret rotation helpers (rotate token + update Keychain, no web UI) ──────
# rotate_metabase — change the Metabase password via API, then update Keychain.
# Prompts (hidden) for the new password; verifies HTTP 200 before saving.
rotate_metabase() {
  local old new id sess code
  old="$(secret get scripbox-metabase)" || { echo "rotate_metabase: no current pw in Keychain" >&2; return 1; }
  printf 'New Metabase password: '; read -rs new; echo
  [ -z "$new" ] && { echo "rotate_metabase: aborted (empty)" >&2; return 1; }
  sess="$(metabase_token)" || { echo "rotate_metabase: auth failed (old pw wrong?)" >&2; return 1; }
  id="$(curl -s -H "X-Metabase-Session: $sess" "$METABASE_URL/api/user/current" | jq -r '.id // empty')"
  [ -z "$id" ] && { echo "rotate_metabase: couldn't resolve user id" >&2; return 1; }
  code="$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$METABASE_URL/api/user/$id/password" \
    -H "X-Metabase-Session: $sess" -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg p "$new" --arg o "$old" '{password:$p, old_password:$o}')")"
  [ "$code" = 200 ] || { echo "rotate_metabase: API HTTP $code — password NOT changed" >&2; return 1; }
  secret set scripbox-metabase "$new" && echo "rotate_metabase: changed + Keychain updated ✓"
}

# rotate_graylog — mint a new Graylog API token, store it in Keychain, then point
# you at the old one to revoke. Needs VPN + your Graylog password (Keychain
# 'scripbox-graylog' or prompted). Verify the token path for your Graylog version
# at $GRAYLOG_BASE_URL/api/api-browser. Open a new shell after rotating so the
# GRAYLOG_API_TOKEN export above picks up the new value.
rotate_graylog() {
  local base="${GRAYLOG_BASE_URL:?GRAYLOG_BASE_URL unset}" user="${GRAYLOG_USER:-$SECRET_ACCOUNT}" pw uid name new
  pw="$(secret get scripbox-graylog 2>/dev/null)"
  [ -z "$pw" ] && { printf 'Graylog password for %s: ' "$user"; read -rs pw; echo; }
  [ -z "$pw" ] && { echo "rotate_graylog: no password" >&2; return 1; }
  uid="$(curl -s -u "$user:$pw" "$base/api/users/$user" | jq -r '.id // empty')"
  [ -z "$uid" ] && { echo "rotate_graylog: user lookup/auth failed (VPN up? see $base/api/api-browser)" >&2; return 1; }
  name="cli-$(date +%Y%m%d)"
  new="$(curl -s -u "$user:$pw" -X POST "$base/api/users/$uid/tokens/$name" \
        -H 'X-Requested-By: cli' -H 'Content-Type: application/json' \
        -d "$(jq -nc --arg p "$pw" '{password:$p}')" | jq -r '.token // empty')"
  [ -z "$new" ] && { echo "rotate_graylog: create failed (older Graylog may need no body; verify at $base/api/api-browser)" >&2; return 1; }
  secret set GRAYLOG_API_TOKEN "$new" && echo "rotate_graylog: new token stored ✓ (open a new shell to re-export)"
  echo "rotate_graylog: revoke OLD tokens → GET $base/api/users/$uid/tokens ; DELETE …/tokens/{id}"
}

# ── Helixa k8s deploy helpers ──────────────────────────────────────────────
# Seed all 6 helixa_app SSM secrets via chamber. Pulls 5 from the Mac Mini's
# .env over SSH (password from Keychain `scripbox-minibot-ssh`) and the 6th
# (claude_code_oauth_token) from Keychain `CLAUDE_CODE_OAUTH_TOKEN`. AWS profile
# + region pre-set; requires `aws sso login --profile production` first.
seed-helixa-secrets() {
  AWS_PROFILE=production AWS_REGION=ap-south-1 \
    bash ~/Documents/seed_helixa_secrets.sh "$@"
}

# Belt-and-braces: starship's init sets `promptsubst`, but if that init ever
# fails to run (PATH gap, partial re-source, etc.) RPROMPT renders the literal
# `$(starship prompt --right …)` string. Re-asserting it here is idempotent
# and guarantees command-substitution in PROMPT/RPROMPT always expands.
setopt PROMPT_SUBST

# ── Claude Code model proxy (routes by model: DeepSeek->OpenRouter, Claude->Anthropic) ──
# proxy     -> check status
# proxy-up  -> start/restart via launchctl
# proxy-down -> stop the proxy
proxy() {
  local raw=$(launchctl list com.claude.model-proxy 2>/dev/null)
  local pid=$(echo "$raw" | sed -n 's/.*"PID"[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p')
  if [[ -n "$pid" ]]; then
    echo "Model proxy running (PID $pid)"
    nc -z 127.0.0.1 9099 &>/dev/null && echo "  port 9099: open" || echo "  port 9099: closed"
  else
    echo "Model proxy NOT running"
    echo "  Run: proxy-up"
  fi
}
proxy-up() {
  launchctl kickstart -kp "gui/$(id -u)/com.claude.model-proxy" 2>/dev/null \
    || launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.claude.model-proxy.plist" 2>/dev/null
  sleep 1
  proxy
}
proxy-down() {
  launchctl bootout "gui/$(id -u)/com.claude.model-proxy" 2>/dev/null && echo "Proxy stopped" || echo "Not running"
}

# Direct-mode fallbacks (bypass proxy, restart Claude Code needed)
ds() {
  ln -sf settings.deepseek.json "$HOME/.claude/settings.json" \
    && echo "Switched to DeepSeek (OpenRouter direct) -- restart Claude Code" \
    || echo "Failed"
}
cc() {
  ln -sf settings.claude.json "$HOME/.claude/settings.json" \
    && echo "Switched to Claude native -- restart Claude Code" \
    || echo "Failed"
}