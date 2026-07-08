#!/usr/bin/env zsh
# tests/dwim-write.zsh — _dwim_confirm previews a dwim-write before asking.
emulate -L zsh
source "${0:A:h}/../files/zsh/dwim.zsh"

fails=0
cache="$(mktemp -d)/dwim"; mkdir -p "$cache"
export XDG_CACHE_HOME="${cache:h}"
print -r -- $'row1\nrow2\nrow3\nrow4' > "$cache/last_answer"

# Feed Esc so _dwim_confirm returns without running anything; capture stderr.
out="$(printf '\e' | _dwim_confirm "dwim-write /tmp/dwim-new.txt" 2>&1 >/dev/null)"
[[ "$out" == *"/tmp/dwim-new.txt"* ]] || { print "FAIL: preview missing path"; fails=1 }
[[ "$out" == *"NEW file"* ]]         || { print "FAIL: missing NEW file marker"; fails=1 }
[[ "$out" == *"row1"* ]]             || { print "FAIL: missing content preview"; fails=1 }

# OVERWRITES branch when the target already exists.
tf="$(mktemp)"; print -n "old" > "$tf"
out2="$(printf '\e' | _dwim_confirm "dwim-write $tf" 2>&1 >/dev/null)"
[[ "$out2" == *"OVERWRITES"* ]] || { print "FAIL: missing OVERWRITES marker"; fails=1 }

# Content with NO trailing newline must still show (a one-line snippet, e.g. a
# .gitignore) — the `|| [[ -n $_l ]]` in the read loop. Byte count shown too.
print -rn -- "node_modules" > "$cache/last_answer"
out3="$(printf '\e' | _dwim_confirm "dwim-write /tmp/dwim-gi.txt" 2>&1 >/dev/null)"
[[ "$out3" == *"node_modules"* ]] || { print "FAIL: no-trailing-newline content dropped"; fails=1 }
[[ "$out3" == *"1 lines"* ]]      || { print "FAIL: line count wrong for no-newline"; fails=1 }
[[ "$out3" == *" B)"* ]]          || { print "FAIL: byte count missing"; fails=1 }

# A QUOTED, tilde path must resolve so OVERWRITES fires on an existing file
# (naive prefix-strip left the quotes and showed NEW over an existing file).
qhome="$(mktemp -d)"; print -rn -- "x" > "$cache/last_answer"
print -n "old" > "$qhome/tt.md"
out4="$(HOME="$qhome"; printf '\e' | _dwim_confirm 'dwim-write "~/tt.md"' 2>&1 >/dev/null)"
[[ "$out4" == *"OVERWRITES"* ]] || { print "FAIL: quoted-tilde path did not resolve to OVERWRITES"; fails=1 }

(( fails )) && { print "FAIL: dwim-write confirm preview"; exit 1 }
print "PASS: dwim-write confirm preview"
