#!/usr/bin/env zsh
# tests/dwim-agent.zsh — the agentic-loop offer wired into the plain fast @ path.
#
# Asserts that _dwim_run_action:
#   (a) classify→"question": read-only action runs unchanged, NO offer shown;
#   (b) classify→"task" but the offer is declined: still runs the read-only
#       action, and NEITHER --plan NOR --do is ever called;
#   (c) classify→"task", offer accepted, plan approved: the confined execute step
#       `dwim-engine --do --plan-file /tmp/x` IS invoked (and the read-only
#       action is NOT — we took the do-loop branch and returned);
#   (c2) classify→"task", offer accepted, but the plan is NOT approved: --plan
#       ran (a plan was generated) yet --do is NOT (cancelled at the gate).
#
# Both the offer and the plan-approval are the run-style consent UI (_dwim_confirm),
# which reads a keypress from the TERMINAL and waits. Non-interactively we can't
# feed that keypress, so — as the other zsh tests do for interactive callees — we
# stub _dwim_confirm. It keys off the prompt text so the two gates are driven
# independently: DWIM_FAKE_OFFER for the "plan & run … do-loop" offer,
# DWIM_FAKE_CONFIRM for the "approve & run this plan" gate.
emulate -L zsh
zmodload zsh/datetime 2>/dev/null

tmp="$(mktemp -d)"
export XDG_CACHE_HOME="$tmp/cache"; mkdir -p "$tmp/cache/dwim"
export ENGINE_LOG="$tmp/engine.log"; export ACTION_LOG="$tmp/action.log"

# --- PATH-shim a fake dwim-engine (classify/plan/do) -------------------------
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

# --- Stub the read-only answer path + the consent UI -------------------------
dwim-action() { print -r -- "ACTION intent=$1" >> "$ACTION_LOG"; }
fzf() { print "FZF-CALLED" >> "$ACTION_LOG"; return 1; }
# The run-style gate, stubbed. Distinguish the OFFER ("plan & run this as a
# do-loop") from the plan-APPROVAL ("approve & run this plan") by prompt text.
_dwim_confirm() {
  case "$1" in
    *do-loop*) [[ "${DWIM_FAKE_OFFER:-yes}"   == yes ]] ;;
    *)         [[ "${DWIM_FAKE_CONFIRM:-yes}" == yes ]] ;;
  esac
}

fails=0

# (a) QUESTION → read-only action runs; offer never shown; no --plan/--do.
: > "$ENGINE_LOG"; : > "$ACTION_LOG"
DWIM_FAKE_KIND=question _dwim_run_action "how does the index work" fast || true
grep -q "ACTION intent=how does the index work" "$ACTION_LOG" \
  || { print "FAIL(a): question must run the read-only action"; fails=1 }
grep -q -- "--plan\|--do" "$ENGINE_LOG" \
  && { print "FAIL(a): a question must not plan or execute"; fails=1 }

# (b) TASK but offer DECLINED → still runs the read-only action; no --plan/--do.
: > "$ENGINE_LOG"; : > "$ACTION_LOG"; _DWIM_SESSION_ID=""
DWIM_FAKE_KIND=task DWIM_FAKE_OFFER=no _dwim_run_action "add a --json flag" fast || true
grep -q "ACTION intent=add a --json flag" "$ACTION_LOG" \
  || { print "FAIL(b): a declined offer must fall through to the read-only action"; fails=1 }
grep -q -- "--plan" "$ENGINE_LOG" \
  && { print "FAIL(b): declining the offer must not run --plan"; fails=1 }
grep -q -- "--do" "$ENGINE_LOG" \
  && { print "FAIL(b): declining the offer must not run --do"; fails=1 }

# (c) TASK, offer ACCEPTED, plan APPROVED → executes via --do; read-only NOT run.
: > "$ENGINE_LOG"; : > "$ACTION_LOG"; _DWIM_SESSION_ID=""
DWIM_FAKE_KIND=task DWIM_FAKE_OFFER=yes DWIM_FAKE_CONFIRM=yes \
  _dwim_run_action "fix the failing test" fast || true
grep -q -- "--do --plan-file /tmp/x" "$ENGINE_LOG" \
  || { print "FAIL(c): an approved plan must execute via --do --plan-file"; fails=1 }
grep -q "ACTION intent=" "$ACTION_LOG" \
  && { print "FAIL(c): an approved do-loop must not also run the read-only action"; fails=1 }

# (c2) TASK, offer ACCEPTED, plan NOT approved → --plan ran, --do did NOT.
: > "$ENGINE_LOG"; : > "$ACTION_LOG"; _DWIM_SESSION_ID=""
DWIM_FAKE_KIND=task DWIM_FAKE_OFFER=yes DWIM_FAKE_CONFIRM=no \
  _dwim_run_action "fix the failing test" fast || true
grep -q -- "--plan" "$ENGINE_LOG" \
  || { print "FAIL(c2): accepting the offer must generate a plan (--plan)"; fails=1 }
grep -q -- "--do" "$ENGINE_LOG" \
  && { print "FAIL(c2): denying the plan gate must not execute"; fails=1 }

(( fails )) && { print "FAIL: dwim-agent offer"; exit 1 }
print "PASS: dwim-agent offer → plan → approve → execute"
