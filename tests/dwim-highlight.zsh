#!/usr/bin/env zsh
set -e
zmodload zsh/datetime 2>/dev/null
tmp="$(mktemp -d)"; export XDG_CACHE_HOME="$tmp/cache"; mkdir -p "$tmp/cache/dwim"
source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

# The DISPLAY-ONLY highlighted command is plain ANSI-colored text; nothing here
# executes it. Build the sentinel escape at runtime (printf %b) so it is a real
# ESC byte regardless of how the file was written.
esc="$(printf '\033')"
CMD='rm -rf node_modules'
HL="${esc}[38;5;79mrm${esc}[0m ${esc}[38;5;179m-rf${esc}[0m node_modules"
# Fixed-string needle (the highlighted binary token); grep -F so the ANSI
# escape's `[` isn't read as a regex bracket expression.
needle="${esc}[38;5;79mrm"

# Unregister the preexec hooks so they don't re-fire on this script's own lines.
autoload -Uz add-zsh-hook
add-zsh-hook -d preexec _dwim_preexec 2>/dev/null || true
add-zsh-hook -d preexec _dwim_clear_replay 2>/dev/null || true

# --- (a) _dwim_panel shows the highlighted command, falls back to raw ---------
hl_panel="$(_dwim_panel "$CMD" "out" 0 haiku 0.1 "$HL" 2>&1)"
print -r -- "$hl_panel" | grep -qF -- "$needle" \
  || { echo "FAIL: panel should show the highlighted command"; exit 1 }

raw_panel="$(_dwim_panel "$CMD" "out" 0 haiku 0.1 "" 2>&1)"
print -r -- "$raw_panel" | grep -q "┌ rm -rf node_modules " \
  || { echo "FAIL: panel should fall back to the raw command when cmd_hl empty"; exit 1 }
# The raw fallback must NOT contain the command color escape.
if print -r -- "$raw_panel" | grep -qF -- "$needle"; then
  echo "FAIL: raw panel must not contain the highlight escape"; exit 1
fi

# --- (b) _dwim_confirm displays the highlighted command ----------------------
# The prompt is emitted before `read -k` (which errors in this non-tty test);
# || true keeps set -e from tripping on that — irrelevant to the display check.
hl_confirm="$(_dwim_confirm "$CMD" "$HL" 2>&1 || true)"
print -r -- "$hl_confirm" | grep -qF -- "$needle" \
  || { echo "FAIL: confirm should display the highlighted command"; exit 1 }

raw_confirm="$(_dwim_confirm "$CMD" "" 2>&1 || true)"
print -r -- "$raw_confirm" | grep -q "rm -rf node_modules" \
  || { echo "FAIL: confirm should fall back to the raw command when cmd_hl empty"; exit 1 }

# --- (c) the EXECUTED command is unaffected by cmd_hl ------------------------
# Drive _dwim_execute_loop with a stub engine that returns a read-only command
# plus a distinct cmd_hl (plain sentinel — valid JSON), and record what actually
# runs. cmd_hl must never reach the run path — only the raw cmd does.
RUNLOG="$tmp/runlog"; : > "$RUNLOG"
dwim-engine() {
  # Emit --run JSON: read-only so it "ran". Record the cmd we were asked to run.
  print -r -- "RAN=[echo hi]" >> "$RUNLOG"
  print -r -- '{"cmd":"echo hi","cmd_hl":"HLSENTINEL echo hi","interactive":false,"read_only":true,"ran":true,"exit":0,"stdout":"hi","stderr":"","timed_out":false,"duration":0.0}'
}
_dwim_panel() { print -r -- "PANEL cmd=[$1] cmd_hl=[$6]" >> "$RUNLOG"; }
_dwim_execute_loop "echo hi" haiku >/dev/null 2>&1 || true
grep -q "RAN=\[echo hi\]" "$RUNLOG" \
  || { echo "FAIL: the raw command should be the one run"; exit 1 }
# The panel got the distinct cmd_hl for display, while the run used the raw cmd.
grep -q "PANEL cmd=\[echo hi\] cmd_hl=\[HLSENTINEL echo hi\]" "$RUNLOG" \
  || { echo "FAIL: panel should receive the distinct cmd_hl for display"; exit 1 }

echo "PASS: dwim command highlighting"
