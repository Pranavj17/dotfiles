#!/usr/bin/env bash
# Regression tests for the statusline renderer.
# Deployed:  bash ~/.claude/statusline/test.sh
# Source:    SL_OVERRIDE=/path/to/statusline-command.sh bash test.sh
set -u
SL="${SL_OVERRIDE:-$HOME/.claude/statusline-command.sh}"
ESC=$'\033'
pass=0; fail=0
G_DIR=$(printf '\xef\x81\xbb')
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
strip(){ sed -E "s/${ESC}\[[0-9;]*m//g"; }
render(){ ( cd /tmp && printf '%s' "$1" | bash "$SL" ); }   # cd /tmp => empty cwd never picks up a stray repo
ok(){ printf '  ok  %s\n' "$1"; pass=$((pass+1)); }
bad(){ printf 'FAIL  %s\n      out: [%s]\n' "$1" "$2"; fail=$((fail+1)); }
ck(){  local o; o=$(render "$2" | strip); case "$o" in *"$3"*) ok "$1";; *) bad "$1 (want: $3)" "$o";; esac; }
nck(){ local o; o=$(render "$2" | strip); case "$o" in *"$3"*) bad "$1 (unwanted: $3)" "$o";; *) ok "$1";; esac; }
ckraw(){ local o; o=$(render "$2"); case "$o" in *"$3"*) ok "$1";; *) bad "$1 (want raw color)" "$(printf '%s' "$o"|strip)";; esac; }

echo "== model transform =="
ck "opus id -> opus-4.7"     '{"model":{"id":"claude-opus-4-7"}}'      "opus-4.7"
ck "haiku id -> haiku-4.5"   '{"model":{"id":"claude-haiku-4-5"}}'     "haiku-4.5"
ck "display_name fallback"   '{"model":{"display_name":"Sonnet X"}}'   "Sonnet X"
ck "[1m] suffix -> opus-4.8" '{"model":{"id":"claude-opus-4-8[1m]"}}'  "opus-4.8"
ck "[1m] tag kept"           '{"model":{"id":"claude-opus-4-8[1m]"}}'  "1m"

echo "== ctx colour + bar =="
ckraw "ctx<50 green"     '{"context_window":{"used_percentage":21}}' "${ESC}[38;2;152;195;121m"
ckraw "ctx 50-79 yellow" '{"context_window":{"used_percentage":67}}' "${ESC}[38;2;229;192;123m"
ckraw "ctx>=80 red"      '{"context_window":{"used_percentage":85}}' "${ESC}[38;2;224;108;117m"
ck    "pct shown"        '{"context_window":{"used_percentage":21}}' "21%"
ck    "bar 5% empty"     '{"context_window":{"used_percentage":5}}'  "${G_BEMPTY}${G_BEMPTY}${G_BEMPTY}${G_BEMPTY}${G_BEMPTY}"
ck    "bar 84% ####_"    '{"context_window":{"used_percentage":84}}' "${G_BFULL}${G_BFULL}${G_BFULL}${G_BFULL}${G_BEMPTY}"

echo "== tokens =="
ck  "k tokens"   '{"context_window":{"total_input_tokens":215000}}'  "215.0k"
ck  "M tokens"   '{"context_window":{"total_input_tokens":1500000}}' "1.5M"
ck  "raw tokens" '{"context_window":{"total_input_tokens":900}}'     "900"
nck "no tokens glyph when absent" '{"cwd":"/tmp"}' "$G_TOK"

echo "== cost =="
ck  "cost 2dp"         '{"cost":{"total_cost_usd":2.3}}' "2.30"
ck  "cost glyph shown" '{"cost":{"total_cost_usd":2.3}}' "$G_COST"

echo "== output style =="
ck  "non-default shown" '{"output_style":{"name":"explanatory"}}' "explanatory"
nck "default hidden"    '{"cwd":"/tmp","output_style":{"name":"default"}}' "default"

echo "== place / glyphs =="
ck "home -> ~"        "{\"cwd\":\"$HOME/x\"}" "~/x"
ck "dir glyph shown"  '{"cwd":"/tmp"}' "$G_DIR"

echo "== grouped join + divider suppression =="
ck  "divider present" '{"cwd":"/tmp","context_window":{"used_percentage":10,"total_input_tokens":1000}}' "$G_BAR"
nck "no git glyph outside repo" '{"cwd":"/tmp"}' "$G_GIT"

echo "== field order (place -> ctx -> style -> usage) =="
o=$(render '{"cwd":"/tmp","model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":21,"total_input_tokens":215000},"cost":{"total_cost_usd":2.34},"output_style":{"name":"explanatory"}}' | strip)
case "$o" in *"opus-4.7"*"21%"*"explanatory"*"2.34"*"215.0k"*) ok "order preserved";; *) bad "order" "$o";; esac

echo "== git chip (branch dirty ahead) =="
W=$(mktemp -d); B=$(mktemp -d)
git init -q --bare "$B/r.git"
git init -q -b main "$W"
git -C "$W" config user.email t@t; git -C "$W" config user.name t
echo a > "$W/a.txt"; git -C "$W" add a.txt; git -C "$W" commit -qm init
git -C "$W" remote add origin "$B/r.git"; git -C "$W" push -q -u origin main
echo x > "$W/b.txt"; git -C "$W" add b.txt; git -C "$W" commit -qm ahead
echo dirty >> "$W/a.txt"
g=$(render "{\"cwd\":\"$W\"}" | strip)
case "$g" in *"main"*)         ok "branch shown";; *) bad "branch" "$g";; esac
case "$g" in *"main${G_DOT}"*)  ok "dirty dot";;   *) bad "dirty" "$g";; esac
case "$g" in *"${G_UP}1"*)      ok "ahead up1";;    *) bad "ahead" "$g";; esac
rm -rf "$W" "$B"

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
