# Put Homebrew binaries ahead of system ones (git, jq, etc.)
export PATH="/opt/homebrew/bin:$PATH"

# Personal scripts (e.g. har-extract)
export PATH="$HOME/.local/bin:$PATH"

# OpenGrok CLI
export PATH="$HOME/.opengrok/bin:$PATH"

# bun's global bin (where `bun install -g <pkg>` puts binaries — e.g. claude)
export PATH="$HOME/.bun/bin:$PATH"

# npm global bin (where `npm i -g <pkg>` puts binaries — e.g. pi)
export PATH="$HOME/.npm-global/bin:$PATH"

# Run all shell-tooling regression tests (statusline + secret helper)
alias shelltest='bash ~/.config/shell-tests/run.sh'

# autojump — `j <partial-dir-name>` jumps to frequently-used directories
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

# ── memory + Headroom ────────────────────────────────────────────────────────
# Grok Build models route through the local Headroom proxy (:8787). Without it
# every model call 404s/refuses.
#
# Deploy once (if missing):  headroom install apply --scope provider
#   (never --scope user — HM owns ~/.zshrc → nix store EACCES)
# One-time MCP/Serena register:  memory-setup
# Day-to-day:                    memory | hr-start | hr-status | hr-dash
#
# 413 / compression timeout: Headroom defaults to fail-CLOSED (HTTP 413) when
# compression times out on large /v1/responses bodies. We pin fail-open + a
# 60s compressor budget on the deploy manifest so Grok keeps working.
#   hr-failopen   — re-apply those env vars + re-render runners (no long restart)
#   hr-restart    — fast launchctl kickstart (NOT `install restart`, which blocks ~45s)

_HEADROOM_PROFILE="${HEADROOM_PROFILE:-default}"
_HEADROOM_LABEL="com.headroom.${_HEADROOM_PROFILE}"
_HEADROOM_DEPLOY="${HOME}/.headroom/deploy/${_HEADROOM_PROFILE}"
_HEADROOM_READY_URL="${HEADROOM_READY_URL:-http://127.0.0.1:8787/readyz}"
# /livez = process liveness (instant 200 while the proxy process is up) — the
# right probe for "is headroom already started". /readyz is TRAFFIC readiness:
# it can take 3–5s and returns 503 while the proxy warms up / a compression
# worker is quarantined. Treating that as "down" made `memory` kickstart -k
# (kill+restart) a perfectly healthy proxy every launch → grok got stuck.
_HEADROOM_LIVE_URL="${HEADROOM_LIVE_URL:-http://127.0.0.1:8787/livez}"

# Persist fail-open + longer compression timeout into the deploy profile.
# Safe to call repeatedly. Re-renders run/ensure scripts from base_env.
_headroom_patch_failopen() {
  local py
  py="$(command -v python3 2>/dev/null || true)"
  # Prefer the headroom tool's interpreter (has headroom.* installed).
  if [[ -x "${HOME}/.local/share/uv/tools/headroom-ai/bin/python" ]]; then
    py="${HOME}/.local/share/uv/tools/headroom-ai/bin/python"
  fi
  [[ -n "$py" ]] || return 1
  "$py" - <<'PY'
from headroom.install.state import load_manifest, save_manifest
from headroom.install.supervisors import render_runner_scripts

profile = __import__("os").environ.get("HEADROOM_PROFILE", "default")
m = load_manifest(profile)
if m is None:
    raise SystemExit(f"no headroom deploy profile '{profile}'")

want = {
    "HEADROOM_WS_FAIL_OPEN_ON_COMPRESSION_FAILURE": "1",
    "HEADROOM_COMPRESSION_TIMEOUT_SECONDS": "60",
}
changed = False
for k, v in want.items():
    if m.base_env.get(k) != v:
        m.base_env[k] = v
        changed = True
if changed:
    save_manifest(m)
    render_runner_scripts(m)
    print(f"headroom: patched fail-open on profile '{profile}'", flush=True)
else:
    # Still re-render if runner scripts drifted (e.g. ensure missing exports).
    run = __import__("pathlib").Path.home() / ".headroom" / "deploy" / profile / "run-headroom.sh"
    text = run.read_text(encoding="utf-8") if run.exists() else ""
    if "HEADROOM_WS_FAIL_OPEN_ON_COMPRESSION_FAILURE" not in text:
        render_runner_scripts(m)
        print(f"headroom: re-rendered runners for profile '{profile}'", flush=True)
PY
}

# Start the launchd agent if it isn't running — NEVER kill a serving proxy.
# Plain `launchctl kickstart` is a no-op when the job is already running; we
# only use `-k` (kill+restart) when the job is loaded but the port is dead
# (hung/stale instance that can't answer — otherwise launchd won't revive it).
_headroom_kickstart() {
  local domain="gui/$(id -u)/${_HEADROOM_LABEL}"
  if launchctl print "$domain" >/dev/null 2>&1; then
    if nc -z 127.0.0.1 8787 >/dev/null 2>&1; then
      launchctl kickstart "$domain" 2>/dev/null && return 0
    else
      launchctl kickstart -k "$domain" 2>/dev/null && return 0
    fi
  fi
  # Fallbacks if launchd job missing / not loaded.
  if [[ -x "${_HEADROOM_DEPLOY}/ensure-headroom.sh" ]]; then
    "${_HEADROOM_DEPLOY}/ensure-headroom.sh" >/dev/null 2>&1 && return 0
  fi
  if command -v headroom >/dev/null 2>&1; then
    headroom install start --profile "$_HEADROOM_PROFILE" >/dev/null 2>&1 && return 0
  fi
  return 1
}

_memory_ensure_headroom() {
  local url="$_HEADROOM_READY_URL"
  # Keep fail-open durable even if a later `install apply` dropped the keys.
  _headroom_patch_failopen >/dev/null 2>&1 || true

  # "Already started?" = process alive (livez), NOT traffic-ready (readyz).
  # readyz can 503 for seconds during warmup/quarantine; that is not "down".
  if curl -sf --max-time 1 "$_HEADROOM_LIVE_URL" >/dev/null 2>&1; then
    return 0
  fi
  echo "headroom: proxy not up — starting (profile ${_HEADROOM_PROFILE})..." >&2
  _headroom_kickstart || true

  local i
  for i in 1 2 3 4 5 6 7 8 9 10 12 14 16 18 20; do
    if curl -sf --max-time 1 "$url" >/dev/null 2>&1; then
      echo "headroom: ready on :8787" >&2
      return 0
    fi
    sleep 0.5
  done
  echo "headroom: still not ready on :8787 — Grok model calls will fail" >&2
  echo "  try: hr-restart   or   headroom doctor" >&2
  return 1
}


_memory_cd_home() {
  local -a saved_chpwd_functions
  saved_chpwd_functions=(${chpwd_functions[@]})
  chpwd_functions=(${chpwd_functions:#autojump_chpwd})
  cd ~
  local cd_status=$?
  chpwd_functions=(${saved_chpwd_functions[@]})
  return $cd_status
}

# Drop any stale aliases so these functions win (older shells / files/zshrc).
# hr-restart / hr-failopen used to be aliases — unalias before defining functions
# or zsh errors with: defining function based on alias `hr-restart'.
unalias memory 2>/dev/null || true
unalias memory-setup 2>/dev/null || true
unalias hr-restart 2>/dev/null || true
unalias hr-failopen 2>/dev/null || true

# `memory` — fast daily launch (Open Grok).
# Uses open-grok (ChatGPT Codex provider) instead of upstream grok.
# Headroom no longer wraps open-grok (no `headroom wrap open-grok` support),
# so we launch the binary directly. Headroom-proxied models still work because
# their base_url in ~/.opengrok/config.toml points at :8787; Codex models use
# the ChatGPT subscription directly.
# Launch from ~ (NOT ~/Documents/memory): rich calls os.getcwd() at import,
# and TCC denies getcwd for processes whose cwd is inside ~/Documents
# (only launchd/TCC-granted processes can read it). The TUI opens the memory
# dir via --cwd.
memory() {
  _memory_cd_home || return 1

  # Session name as project identifier for headroom stats.
  # Usage: `memory fix-oauth` → project: memory-fix-oauth.
  # Without args, falls back to TTY (ttys001) → pid → random.
  local proj_suffix
  # First non-flag argument is the session name
  if [[ $# -gt 0 && "$1" != -* ]]; then
    proj_suffix="$1"
    shift
  elif [[ -t 0 ]]; then
    proj_suffix=$(tty 2>/dev/null | sed 's|.*/||' | tr '/' '-')
  fi
  [[ -z "$proj_suffix" ]] && proj_suffix="pid-$$"
  [[ -z "$proj_suffix" ]] && proj_suffix="rnd-${RANDOM}"

  if ! curl -sf --max-time 1 "${_HEADROOM_LIVE_URL}" >/dev/null 2>&1; then
    _memory_ensure_headroom || true
  else
    # Proxy already up — still keep fail-open pinned (cheap, no restart).
    _headroom_patch_failopen >/dev/null 2>&1 || true
  fi
  exec open-grok \
    --permission-mode bypassPermissions \
    --cwd "$HOME/Documents/memory" "$@"
}

# `memory-setup` — one-shot: register headroom MCP + Serena (slow pre-index OK).
memory-setup() {
  _memory_cd_home || return 1
  _memory_ensure_headroom || true
  headroom wrap grok --no-proxy --prepare-only
  echo "memory-setup: MCP registered. Use \`memory\` for fast daily launch." >&2
}

# Headroom shortcuts (same deploy as Grok / memory workflow)
alias hr='headroom'
alias hr-start='headroom install start --profile default'
alias hr-stop='headroom install stop --profile default'
# Fast restart — do not use `headroom install restart` (blocks ~45s on readyz).
hr-restart() {
  _headroom_patch_failopen || true
  echo "headroom: kickstarting ${_HEADROOM_LABEL}..." >&2
  _headroom_kickstart || {
    echo "headroom: kickstart failed; falling back to install restart" >&2
    headroom install restart --profile "$_HEADROOM_PROFILE"
    return $?
  }
  local i url="$_HEADROOM_READY_URL"
  for i in 1 2 3 4 5 6 7 8 9 10 12 14 16 18 20; do
    if curl -sf --max-time 1 "$url" >/dev/null 2>&1; then
      echo "headroom: ready on :8787" >&2
      return 0
    fi
    sleep 0.5
  done
  echo "headroom: not ready after kickstart" >&2
  return 1
}
hr-failopen() {
  _headroom_patch_failopen && echo "headroom: fail-open OK (restart with hr-restart to load into live process)" >&2
}
alias hr-status='headroom install status --profile default; echo; headroom doctor'
alias hr-dash='headroom dashboard'
alias hr-savings='headroom savings'
alias hr-up='_memory_ensure_headroom && headroom doctor'

# `nse <command>` — nanosb exec on the latest sandbox (no full UUID needed)
# Usage: nse bash, nse claude, nse ls -la
nse() {
  local id
  id="$(nanosb ps --format json | jq -r '.[0].id // empty')"
  if [[ -z "$id" ]]; then
    echo "No running sandbox. Start one first: nanosb run --name my-vm <image>" >&2
    return 1
  fi
  nanosb exec "$id" "$@"
}

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

# OpenRouter (Anthropic API proxy) — routed via `claude model proxy`.
# Key in Keychain via `secret set OPENROUTER_API_KEY <sk-or-v1-...>`.
export ANTHROPIC_API_KEY="$(secret get OPENROUTER_API_KEY 2>/dev/null)"

# Parallel.ai — web-search/extract MCP (search.parallel.ai). Key in Keychain.
# Rotate at platform.parallel.ai → `secret set PARALLEL_API_KEY <new>`.
export PARALLEL_API_KEY="$(secret get PARALLEL_API_KEY 2>/dev/null)"

# Headroom local proxy (dashboard http://127.0.0.1:8787).
# Deploy once: headroom deploy --no-docker --scope provider
# Daily: memory (auto-starts) | hr-start | hr-status | hr-dash  (see aliases above)
# Do NOT export HEADROOM_BACKEND / HEADROOM_MODE / HEADROOM_PORT / etc. here —
# those override the dashboard Settings UI ("edits have no effect until unset").
# Runtime config: ~/.headroom/deploy/default/manifest.json + launchd
# Route Claude/Codex SDKs through the local proxy (manifest tool_envs).
export ANTHROPIC_BASE_URL="http://127.0.0.1:8787"
export ENABLE_TOOL_SEARCH="true"
export OPENAI_BASE_URL="http://127.0.0.1:8787/v1"

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
