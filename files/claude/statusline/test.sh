#!/usr/bin/env bash
# Regression tests for ~/.claude/statusline-command.sh  (run: bash ~/.claude/statusline/test.sh)
# Self-contained — no bats. Covers the two real bugs we hit: field misalignment
# (tab-IFS collapse) and GNU-vs-BSD stat, plus every rendered chip.
set -u
SL="$HOME/.claude/statusline-command.sh"
ESC=$'\033'
pass=0; fail=0
strip(){ sed -E "s/${ESC}\[[0-9;]*m//g"; }
render(){ printf '%s' "$1" | bash "$SL"; }            # raw (with ANSI)
ok(){ printf '  ok  %s\n' "$1"; pass=$((pass+1)); }
bad(){ printf 'FAIL  %s\n      out: [%s]\n' "$1" "$2"; fail=$((fail+1)); }
ck(){  local o; o=$(render "$2" | strip); case "$o" in *"$3"*) ok "$1";; *) bad "$1 (want: $3)" "$o";; esac; }
nck(){ local o; o=$(render "$2" | strip); case "$o" in *"$3"*) bad "$1 (unwanted: $3)" "$o";; *) ok "$1";; esac; }
ckraw(){ local o; o=$(render "$2"); case "$o" in *"$3"*) ok "$1";; *) bad "$1 (want raw color)" "$(printf '%s' "$o"|strip)";; esac; }

# keep import chip quiet during non-import tests; restore on exit
IMP=/tmp/.claude-import; IMP_SAVE=$(cat "$IMP" 2>/dev/null || true)
printf '0' > "$IMP"
trap '[ -n "$IMP_SAVE" ] && printf "%s" "$IMP_SAVE" > "$IMP" || rm -f "$IMP"' EXIT

echo "== model transform =="
ck "opus id -> opus-4.7"    '{"model":{"id":"claude-opus-4-7"}}'   "opus-4.7"
ck "haiku id -> haiku-4.5"  '{"model":{"id":"claude-haiku-4-5"}}'  "haiku-4.5"
ck "display_name fallback"  '{"model":{"display_name":"Sonnet X"}}' "Sonnet X"

echo "== ctx colour thresholds =="
ckraw "ctx<50 green"     '{"context_window":{"used_percentage":21}}' "${ESC}[32mctx:21%"
ckraw "ctx 50-79 yellow" '{"context_window":{"used_percentage":67}}' "${ESC}[33mctx:67%"
ckraw "ctx>=80 red"      '{"context_window":{"used_percentage":85}}' "${ESC}[31mctx:85%"

echo "== tokens formatting =="
ck  "k tokens"   '{"context_window":{"total_input_tokens":215000}}'  "215.0k tokens"
ck  "M tokens"   '{"context_window":{"total_input_tokens":1500000}}' "1.5M tokens"
ck  "raw tokens" '{"context_window":{"total_input_tokens":900}}'     "900 tokens"
nck "no tokens"  '{}' "tokens"

echo "== cost =="
ck  "cost 2dp"   '{"cost":{"total_cost_usd":2.3}}' "\$2.30"
nck "no cost"    '{}' "\$"

echo "== output style =="
ck  "non-default shown" '{"output_style":{"name":"explanatory"}}' "explanatory"
nck "default hidden"    '{"output_style":{"name":"default"}}'     "default"

echo "== cwd / signature / minimal =="
ck  "home -> ~"          "{\"cwd\":\"$HOME/x\"}" "~/x"
ck  "signature present"  '{}' "🫡"
nck "minimal: no git ("  '{"cwd":"/tmp"}' "("

echo "== field alignment (tab-IFS regression) =="
o=$(render '{"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":21,"total_input_tokens":215000},"cost":{"total_cost_usd":2.34},"output_style":{"name":"explanatory"}}' | strip)
case "$o" in *"ctx:21%"*"explanatory"*"\$2.34"*"215.0k tokens"*) ok "no field shift";; *) bad "field shift" "$o";; esac

echo "== git chip (branch* ↑N) =="
W=$(mktemp -d); B=$(mktemp -d)
git init -q --bare "$B/r.git"
git init -q -b main "$W"
git -C "$W" config user.email t@t; git -C "$W" config user.name t
echo a > "$W/a.txt"; git -C "$W" add a.txt; git -C "$W" commit -qm init
git -C "$W" remote add origin "$B/r.git"; git -C "$W" push -q -u origin main
echo x > "$W/b.txt"; git -C "$W" add b.txt; git -C "$W" commit -qm ahead   # +1 ahead
echo dirty >> "$W/a.txt"                                                    # unstaged
g=$(render "{\"cwd\":\"$W\"}" | strip)
case "$g" in *"(main"*) ok "branch shown";;  *) bad "branch" "$g";; esac
case "$g" in *"main*"*)  ok "dirty marker";;  *) bad "dirty" "$g";; esac
case "$g" in *"↑1"*)     ok "ahead ↑1";;      *) bad "ahead" "$g";; esac
rm -rf "$W" "$B"

echo "== import chip (file-as-state) =="
printf '3' > "$IMP"; ck  "import shows ⟳ 3" '{}' "⟳ 3"
printf '0' > "$IMP"; nck "import 0 hidden"  '{}' "⟳"

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
