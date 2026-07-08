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

(( fails )) && { print "FAIL: dwim-write confirm preview"; exit 1 }
print "PASS: dwim-write confirm preview"
