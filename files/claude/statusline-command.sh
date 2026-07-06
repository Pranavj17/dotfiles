#!/usr/bin/env bash
# Claude Code statusline - grouped multi-chip renderer.
#
# Render is FAST and never blocks: every chip comes from the stdin JSON (parsed
# in ONE jq call) and ONE `git status` call. No background probes.
#
# Layout: 5 groups joined by a dim divider, empty groups suppressed:
#   [dir] cwd [chip] model | [gauge] ctx% bar | [branch] git | style | [$] cost [db] tokens
# Nerd Font glyphs are emitted as printf-hex so this source stays pure ASCII
# (avoids \uXXXX mangling and the bash-4 \u dependency; works on bash 3.2 too).
set -u
input=$(cat)

# ---- colours (truecolor) ----
R=$'\033[0m'; DIM=$'\033[2m'
ACC=$'\033[38;2;232;97;26m'    # scripbox orange accent (dirty dot / emphasis)
WHT=$'\033[38;2;220;223;228m'  # bright text (path, branch name)
GRY=$'\033[38;2;122;128;138m'  # glyph grey
DGY=$'\033[38;2;92;99;112m'    # dividers, empty bar cells
PUR=$'\033[38;2;198;120;221m'  # git branch
TGRN=$'\033[38;2;152;195;121m' # ctx ok, cost
TYEL=$'\033[38;2;229;192;123m' # ctx warn
TRED=$'\033[38;2;224;108;117m' # ctx danger
TBLU=$'\033[38;2;97;175;239m'  # tokens, style, ahead

# ---- glyphs (Nerd Font) ----
G_DIR=$(printf '\xef\x81\xbb')
G_MODEL=$(printf '\xef\x8b\x9b')
G_CTX=$(printf '\xef\x83\xa4')
G_GIT=$(printf '\xee\x82\xa0')
G_COST=$(printf '\xef\x85\x95')
G_TOK=$(printf '\xef\x87\x80')
G_STYLE=$(printf '\xef\x87\xbc')
G_DOT=$(printf '\xe2\x97\x8f')
G_UP=$(printf '\xe2\x86\x91')
G_BAR=$(printf '\xe2\x94\x82')
G_BFULL=$(printf '\xe2\x96\x88')
G_BEMPTY=$(printf '\xe2\x96\x91')

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

groups=()
gadd() { [ -n "${1:-}" ] && groups+=("$1"); }

# --- group 1: place (dir + model) ---
case "$f_cwd" in "$HOME"*) cwd="~${f_cwd#"$HOME"}";; *) cwd="$f_cwd";; esac
place="${GRY}${G_DIR}${R} ${WHT}${cwd}${R}"
raw="$f_mid"; [ -z "$raw" ] && raw="$f_mname"
if [ -n "$raw" ]; then
  # keep a trailing [..] id suffix (e.g. [1m]) as a dim tag; the -N-N$ dot
  # transform can't match while the suffix is attached, so strip it first.
  tag=""
  case "$raw" in *\[*\]) tag="${raw##*\[}"; tag="${tag%\]}"; raw="${raw%%\[*}";; esac
  model=$(printf '%s' "$raw" | sed -E 's/^claude-//; s/-([0-9]+)-([0-9]+)$/-\1.\2/')
  place="${place}  ${DIM}${G_MODEL} ${model}${R}"
  [ -n "$tag" ] && place="${place}${DIM} ${tag}${R}"
fi
gadd "$place"

# --- group 2: ctx (% + 5-cell bar, colour-graded) ---
if [ -n "$f_pct" ]; then
  p=$(printf '%.0f' "$f_pct")
  if   [ "$p" -ge 80 ]; then c=$TRED
  elif [ "$p" -ge 50 ]; then c=$TYEL
  else c=$TGRN; fi
  fill=$(( p / 20 )); [ "$fill" -gt 5 ] && fill=5; [ "$fill" -lt 0 ] && fill=0
  bar=""; i=0
  while [ "$i" -lt 5 ]; do
    if [ "$i" -lt "$fill" ]; then bar="${bar}${G_BFULL}"; else bar="${bar}${G_BEMPTY}"; fi
    i=$(( i + 1 ))
  done
  gadd "${c}${G_CTX} ${p}% ${DGY}${bar}${R}"
fi

# --- group 3: git (branch dirty ahead) - single porcelain call ---
g=$(GIT_OPTIONAL_LOCKS=0 git -C "$f_cwd" status --porcelain=2 --branch 2>/dev/null)
if [ -n "$g" ]; then
  br=$(printf '%s\n' "$g"  | awk '/^# branch.head /{print $3; exit}')
  ab=$(printf '%s\n' "$g"  | awk '/^# branch.ab /{print $3; exit}')
  ndirty=$(printf '%s\n' "$g" | awk '!/^#/{c++} END{print c+0}')
  [ "$br" = "(detached)" ] && br="detached"
  dirty=""; [ "${ndirty:-0}" -gt 0 ] && dirty="${ACC}${G_DOT}${R}"
  up=""; ahead=${ab#+}; [ -n "$ab" ] && [ "${ahead:-0}" -gt 0 ] && up=" ${TBLU}${G_UP}${ahead}${R}"
  gadd "${PUR}${G_GIT}${R} ${WHT}${br}${R}${dirty}${up}"
fi

# --- group 4: output style (hidden when default) ---
[ "$f_ostyle" = "default" ] && f_ostyle=""
[ -n "$f_ostyle" ] && gadd "${TBLU}${G_STYLE} ${f_ostyle}${R}"

# --- group 5: usage (cost + tokens) ---
usage=""
[ -n "$f_cost" ] && usage="${TGRN}${G_COST} $(awk "BEGIN{printf \"%.2f\", $f_cost}")${R}"
if [ -n "$f_ctok" ]; then
  if   [ "$f_ctok" -ge 1000000 ]; then ts=$(awk "BEGIN{printf \"%.1fM\", $f_ctok/1000000}")
  elif [ "$f_ctok" -ge 1000 ];    then ts=$(awk "BEGIN{printf \"%.1fk\", $f_ctok/1000}")
  else ts="$f_ctok"; fi
  tk="${TBLU}${G_TOK} ${ts}${R}"
  if [ -n "$usage" ]; then usage="${usage}  ${tk}"; else usage="$tk"; fi
fi
gadd "$usage"

# --- join non-empty groups with a dim divider ---
sep=" ${DGY}${G_BAR}${R} "
out=""
for gp in "${groups[@]}"; do out="${out}${out:+$sep}${gp}"; done
printf '%s\n' "$out"
