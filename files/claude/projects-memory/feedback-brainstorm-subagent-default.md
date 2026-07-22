---
name: feedback-brainstorm-subagent-default
description: "After brainstorming → writing-plans, default to subagent-driven execution without asking — don't pause to offer \"subagent vs inline\" choice"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2da146c5-7207-4c6e-a3d0-5930eecb7976
---

After the brainstorming skill produces a written + committed spec and the writing-plans skill produces a committed plan, **default straight to subagent-driven execution**. Skip the "two execution options" prompt the writing-plans skill scripts at the end.

**Why:** The user has consistently picked subagent-driven every time the choice is offered. Pausing to ask is wasted ceremony — it interrupts flow and adds a round-trip for no decision. The two-stage review inside subagent-driven-development already gives the user the checkpoints they care about; the "which mode" question is asking about a preference they've already made.

**How to apply:**
- Brainstorming → writing-plans → **immediately invoke `superpowers:subagent-driven-development`** for the freshly-committed plan. No "which approach?" question in between.
- If the user explicitly wants inline execution, they'll say so — the subagent-driven default is overridden by an explicit instruction, never by inference.
- This is specifically the brainstorming-flow handoff. Don't generalise to other "offer choices" prompts elsewhere (those may have real per-task variance).

Related: [[advisory-fp-title-merge-bug]] (an example brainstorm-spec-plan flow this preference applies to).
