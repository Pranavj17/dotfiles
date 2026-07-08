#!/usr/bin/env zsh
# tests/dwim-agent.zsh — the agentic-loop offer wired into the plain fast @ path.
#
# Asserts that _dwim_run_action:
#   (a) classify→"question": read-only action runs unchanged, NO offer shown;
#   (b) classify→"task" but the offer is declined (read -q gets 'n'): still runs
#       the read-only action, and NEITHER --plan NOR --do is ever called;
#   (c) classify→"task", offer accepted (read -q gets 'y'), --plan emits a plan +
#       a DWIM_PLAN_READY sentinel, and _dwim_confirm auto-approves: the confined
#       execute step `dwim-engine --do --plan-file /tmp/x` IS invoked.
#
# Interactive prompt handling: `read -q` inside _dwim_run_action reads one key
# from stdin, so each call is driven by piping 'y'/'n' into the function. The
# consent gate (_dwim_confirm) is stubbed to a deterministic yes/no rather than
# feeding a keystroke, matching how the other zsh tests stub interactive callees.
emulate -L zsh
zmodload zsh/datetime 2>/dev/null

tmp="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp/cache"; mkdir -p "$tmp/cache/dwim"
export ENGINE_LOG="$tmp/engine.log"; export ACTION_LOG="$tmp/action.log"

# --- PATH-shim a fake dwim-engine (classify/plan/do) -------------------------
# It logs every invocation's argv and answers per flag. $DWIM_FAKE_KIND lets a
# test choose the classify verdict per call.
cat > "$tmp/dwim-engine" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "$ENGINE_LOG"
case "$1" in
  --classify) print -r -- "${DWIM_FAKE_KIND:-question}" ;;
  --plan)
    print -- "PLAN"
    print -- "1. edit a.py — guard"
    print -- "2. run pytest -q — verify"
    print -- "DWIM_PLAN_READY /tmp/x"
    ;;
  --do) print -- "done: 1 file changed, tests green" ;;
esac
EOF
chmod +x "$tmp/dwim-engine"
export PATH="$tmp:$PATH"

source "${0:A:h}/../files/zsh/dwim.zsh" 2>/dev/null || true

# --- Stub the read-only answer path + downstream picker ----------------------
# dwim-action is the read-only answer call; a function overrides PATH lookup and
# emits NO candidates so _dwim_run_action short-circuits before fzf/panel.
dwim-action() { print -r -- "ACTION intent=$1" >> "$ACTION_LOG"; }
fzf() { print "FZF-CALLED" >> "$ACTION_LOG"; return 1; }
# Deterministic consent: default approve; a test flips $DWIM_FAKE_CONFIRM.
_dwim_confirm() { [[ "${DWIM_FAKE_CONFIRM:-yes}" == yes ]]; }

fails=0

# (a) QUESTION → read-only action runs; the offer is never shown, and --plan/--do
#     are never called.
: > "$ENGINE_LOG"; : > "$ACTION_LOG"
DWIM_FAKE_KIND=question _dwim_run_action "how does the index work" fast < /dev/null || true
grep -q "ACTION intent=how does the index work" "$ACTION_LOG" \
  || { print "FAIL(a): question must run the read-only action"; fails=1 }
grep -q -- "--plan\|--do" "$ENGINE_LOG" \
  && { print "FAIL(a): a question must not plan or execute"; fails=1 }

# (b) TASK but offer DECLINED ('n') → still runs the read-only action; NO --plan,
#     NO --do.
: > "$ENGINE_LOG"; : > "$ACTION_LOG"; _DWIM_SESSION_ID=""
printf 'n' | { DWIM_FAKE_KIND=task _dwim_run_action "add a --json flag" fast } || true
grep -q "ACTION intent=add a --json flag" "$ACTION_LOG" \
  || { print "FAIL(b): a declined offer must fall through to the read-only action"; fails=1 }
grep -q -- "--plan" "$ENGINE_LOG" \
  && { print "FAIL(b): declining must not run --plan"; fails=1 }
grep -q -- "--do" "$ENGINE_LOG" \
  && { print "FAIL(b): declining must not run --do"; fails=1 }

# (c) TASK, offer ACCEPTED ('y'), consent auto-yes → the confined execute step
#     `dwim-engine --do --plan-file /tmp/x` IS invoked, and the read-only action
#     is NOT (we took the do-loop branch and returned).
: > "$ENGINE_LOG"; : > "$ACTION_LOG"; _DWIM_SESSION_ID=""
printf 'y' | { DWIM_FAKE_KIND=task DWIM_FAKE_CONFIRM=yes _dwim_run_action "fix the failing test" fast } || true
grep -q -- "--do --plan-file /tmp/x" "$ENGINE_LOG" \
  || { print "FAIL(c): an approved plan must execute via --do --plan-file"; fails=1 }
grep -q "ACTION intent=" "$ACTION_LOG" \
  && { print "FAIL(c): an approved do-loop must not also run the read-only action"; fails=1 }

# (c2) TASK, offer ACCEPTED ('y'), but consent DENIED → NO --do (cancelled).
: > "$ENGINE_LOG"; : > "$ACTION_LOG"; _DWIM_SESSION_ID=""
printf 'y' | { DWIM_FAKE_KIND=task DWIM_FAKE_CONFIRM=no _dwim_run_action "fix the failing test" fast } || true
grep -q -- "--do" "$ENGINE_LOG" \
  && { print "FAIL(c2): denying the consent gate must not execute"; fails=1 }

(( fails )) && { print "FAIL: dwim-agent offer"; exit 1 }
print "PASS: dwim-agent offer → plan → approve → execute"
