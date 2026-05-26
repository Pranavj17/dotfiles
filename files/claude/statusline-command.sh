#!/usr/bin/env bash
# Claude Code statusline — multi-chip renderer.
#
# Design (from the pranavjagadish.com/statusline case study):
#   - Render is FAST and never blocks: deterministic chips come from the stdin JSON
#     (parsed in ONE jq call) and ONE `git status` call; network/AI chips are
#     "file-as-state" — read from /tmp/.claude-* files written by the helper
#     scripts in ~/.claude/statusline/. A missing/stale file just hides its chip.
#   - When a cached file is stale, the renderer forks its refresher DETACHED and
#     returns immediately; the fresh value appears on a later render tick.
#
# Chips: 🫡 cwd · model · ctx% · (git* ↑N) · ⟳import · style · $cost · tokens
#        (import is file-as-state from /tmp/.claude-import; the rest are from stdin JSON)
set -u
input=$(cat)
now=$(date +%s)
HELP="$HOME/.claude/statusline"

# ---- colours ----
R=$'\033[0m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YEL=$'\033[33m'
RED=$'\033[31m'; CYN=$'\033[36m'; MAG=$'\033[35m'; BLU=$'\033[34m'

# GNU coreutils stat uses -c %Y; BSD stat uses -f %m. Try GNU first (all-Nix
# machine), fall back to BSD, default 0 so arithmetic never breaks.
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# fork refresher detached if state file is missing/stale (and unlocked)
refresh() { # $1=statefile $2=ttl $3=script [args...]
  local f="$1" ttl="$2"; shift 2
  local script="$1"; shift
  [ -x "$script" ] || return 0
  [ -d "${f}.lock" ] && return 0
  if [ -f "$f" ]; then
    [ $(( now - $(mtime "$f") )) -lt "$ttl" ] && return 0
  fi
  ( "$script" "$@" >/dev/null 2>&1 & ) >/dev/null 2>&1
}

fresh_read() { # $1=file $2=maxage -> contents only if newer than maxage
  [ -f "$1" ] || return 0
  [ $(( now - $(mtime "$1") )) -le "$2" ] && cat "$1"
}

# ---- parse ALL JSON fields in one jq call ----
# One field per line; mapfile -t keeps blank lines, so empty fields stay aligned
# (a tab/space IFS `read` would collapse them and shift every field).
mapfile -t F < <(
  printf '%s' "$input" | jq -r '[
    (.workspace.current_dir // .cwd // ""),
    (.model.id // ""),
    (.model.display_name // ""),
    (.context_window.used_percentage // ""),
    (.context_window.total_input_tokens // ""),
    (.session_name // ""),
    (.output_style.name // ""),
    (.cost.total_cost_usd // "")
  ] | map(tostring) | .[]' 2>/dev/null
)
f_cwd=${F[0]:-}; f_mid=${F[1]:-}; f_mname=${F[2]:-}; f_pct=${F[3]:-}
f_ctok=${F[4]:-}; f_sname=${F[5]:-}; f_ostyle=${F[6]:-}; f_cost=${F[7]:-}

# kick off background refreshers (non-blocking)
refresh /tmp/.claude-import 60   "$HELP/probe-import.sh"

parts=()
add() { [ -n "${1:-}" ] && parts+=("$1"); }

# --- signature ---
add "🫡"

# --- cwd (~) ---
case "$f_cwd" in "$HOME"*) cwd="~${f_cwd#"$HOME"}";; *) cwd="$f_cwd";; esac
add "$cwd"

# --- model: claude-opus-4-7 -> opus-4.7 ---
model=$(printf '%s' "$f_mid" | sed -E 's/^claude-//; s/-([0-9]+)-([0-9]+)$/-\1.\2/')
[ -z "$model" ] && model="$f_mname"
add "${model:+${DIM}${model}${R}}"

# --- ctx% (colour-graded) ---
if [ -n "$f_pct" ]; then
  p=$(printf '%.0f' "$f_pct")
  if   [ "$p" -ge 80 ]; then c=$RED
  elif [ "$p" -ge 50 ]; then c=$YEL
  else c=$GRN; fi
  add "${c}ctx:${p}%${R}"
fi

# --- git: (branch* ↑N) — single `git status --porcelain=2 --branch` call ---
g=$(GIT_OPTIONAL_LOCKS=0 git -C "$f_cwd" status --porcelain=2 --branch 2>/dev/null)
if [ -n "$g" ]; then
  br=$(printf '%s\n' "$g"  | awk '/^# branch.head /{print $3; exit}')
  ab=$(printf '%s\n' "$g"  | awk '/^# branch.ab /{print $3; exit}')   # +N
  ndirty=$(printf '%s\n' "$g" | awk '!/^#/{c++} END{print c+0}')
  [ "$br" = "(detached)" ] && br="detached"
  dirty=""; [ "${ndirty:-0}" -gt 0 ] && dirty="${YEL}*${R}"
  up=""; ahead=${ab#+}; [ -n "$ab" ] && [ "${ahead:-0}" -gt 0 ] && up=" ${CYN}↑${ahead}${R}"
  add "${DIM}(${R}${br}${dirty}${up}${DIM})${R}"
fi

# --- contexts needing import ---
imp=$(cat /tmp/.claude-import 2>/dev/null)
[ -n "$imp" ] && [ "$imp" != "0" ] && add "${MAG}⟳${R} ${imp}"

# --- output style (hidden when default) ---
[ "$f_ostyle" = "default" ] && f_ostyle=""
add "${f_ostyle:+${BLU}${f_ostyle}${R}}"

# --- session cost ---
[ -n "$f_cost" ] && add "${GRN}\$$(awk "BEGIN{printf \"%.2f\", $f_cost}")${R}"

# --- tokens (rightmost), like /context ("192.8k tokens") ---
if [ -n "$f_ctok" ]; then
  if   [ "$f_ctok" -ge 1000000 ]; then ts=$(awk "BEGIN{printf \"%.1fM\", $f_ctok/1000000}")
  elif [ "$f_ctok" -ge 1000 ];    then ts=$(awk "BEGIN{printf \"%.1fk\", $f_ctok/1000}")
  else ts="$f_ctok"; fi
  add "${DIM}${ts} tokens${R}"
fi

# join with spaces
out=""
for p in "${parts[@]}"; do out="${out}${out:+ }${p}"; done
printf '%s\n' "$out"
