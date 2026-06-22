---
name: yolo
description: Drives a task end-to-end in one autonomous, no-gate pass. Still asks clarifying questions when the target is genuinely ambiguous (batched up front with concrete options), but then skips all spec/plan/approval gates, never blocks on verification, implements everything across all files and wiring, and hands back an assumptions log plus a test plan for the user to run later. Use ONLY when the user explicitly opts in with "yolo", "yolo mode", "full send", "do everything I'll test later", or "no gates". The single remaining hard stop is genuinely irreversible external side effects (force-push, prod deploy, rm -rf, dropping data, moving money, sending external comms). Do NOT auto-trigger on urgency words like "quick" or "simple" — that is fast-implementation; YOLO must be explicitly requested because it disables the approval and verification gates the rest of the system relies on.
---

# YOLO

## Overview

The lifecycle skills are deliberately gated: clarify, spec, plan, approve, slice, verify, review, ship — each a checkpoint that can stop progress. YOLO is the **opposite mode**: one uninterrupted autonomous pass that does everything that can be done, then hands the user a record to test against later. It removes the *process* gates (approval, per-slice checkpoints, blocking on green tests) — but it keeps the one input it cannot fabricate: **a correct understanding of the target**. So YOLO still asks clarifying questions when the goal is genuinely ambiguous. It clarifies the *what*, then full-sends the *how*.

This is a power tool. It trades the safety the rest of the system provides for raw throughput, on the explicit understanding that the user will verify afterward. It must be opted into by name.

## When to Use

Use **only** when the user explicitly opts in, e.g.:

- "yolo" / "yolo mode" / "full send"
- "just do everything, I'll test it later"
- "no gates, build the whole thing"

**Do NOT use when:**

- The user only signalled urgency ("quick", "simple", "small") without opting into YOLO → `fast-implementation`
- No explicit YOLO request was made → run the normal gated lifecycle (`using-agent-skills`)
- The user wants to review/approve before code lands → that is exactly the gate YOLO removes; use the standard skills

YOLO never *auto*-fires. Firing it silently would disable the approval and verification gates the rest of the system depends on.

## The Workflow

```
Explicit YOLO opt-in
    │
    ▼
1. CLARIFY THE TARGET  ── material ambiguity? ──→ batch all questions up front, get answers
    │                                              (minor ambiguity → log an assumption, do NOT ask)
    ▼
2. BLITZ THE PLAN      → terse inline outline, no approval, no waiting
    ▼
3. BUILD EVERYTHING    → all files, wiring, edge cases — the whole thing, not one slice
    ▼
4. SELF-CHECK (non-blocking) → run cheap checks; RECORD failures, never stop/loop/wait on them
    ▼
5. HANDOFF             → assumptions log + change summary + test plan + known gaps/risks
    │
    └── Before any IRREVERSIBLE EXTERNAL action → surface it first (the one hard stop)
```

### 1. Clarify the target (the one step that stays)

If the goal has a **material fork** — divergent interpretations that would produce different software — ask. Batch every such question up front in one pass (use the `question` tool with 3 concrete proposals each per the repo convention), get answers, then do not return to ask again. For **minor** ambiguity (naming, cosmetic choices, reversible defaults), log an assumption and keep moving. Clarify the *what*; never turn this into an approval gate on the *how*.

### 2. Blitz the plan

Collapse spec + task-breakdown into a terse outline you can hold in one message. No spec doc, no approval, no waiting. State assumptions inline and proceed in the same turn.

### 3. Build everything

Implement the **entire** thing end to end: every file, all the wiring that makes it actually run, the obvious edge cases. Do not stop at a thin slice and ask "continue?". Batch edits, read in parallel, keep scope to the task (no unsolicited renovation), and push to a coherent, runnable whole.

### 4. Self-check, non-blocking

Run the cheap checks (build, type-check, lint, targeted tests) if they're readily available — but **never block, loop, or wait** on them. A red result is recorded in the handoff, not a stop sign. Thorough verification is explicitly deferred to the user. This is the "let the user test later" contract.

### 5. Handoff (the deliverable)

End every YOLO run with a concise report — this is what makes "test later" possible:

```
YOLO RUN COMPLETE
- Assumptions: every assumption made instead of asking
- Changed: files touched + what each does
- Test this: concrete steps/commands for the user to verify
- Gaps/risks: anything skipped, unfinished, or that failed a self-check
```

## The One Hard Stop

Everything reversible is full-send. Before any **genuinely irreversible external side effect**, stop and surface it first — do not perform it silently:

- `git push --force`, deleting remote branches/tags
- Deploying/releasing to production
- `rm -rf` or deletes outside the workspace, mass file destruction
- `DROP`/`TRUNCATE`, destructive migrations, wiping data
- Moving money, hitting paid/charging endpoints
- Sending external communications (emails, messages, posting publicly)
- Rotating/exposing secrets or credentials

"Let the user test later" presupposes the user's work still exists to test. Speed on reversible work never licenses irreversible damage.

## Common Rationalizations

YOLO's failure mode is bidirectional: creeping *back* into gating, or running *past* the one hard stop.

| Rationalization | Reality |
|---|---|
| "Let me get my plan approved before building." | Approval is the gate YOLO removes. Clarify the target, then build — don't checkpoint the how. |
| "Every ambiguity deserves a question." | Only **material** forks get a question. Minor/reversible ambiguity is a logged assumption. Question-spam is just gating in disguise. |
| "I'll build one slice and ask whether to continue." | YOLO does the whole thing in one pass. Per-slice approval is a removed gate. |
| "I'll wait until the tests are green before moving on." | Self-check is non-blocking. Record the result and keep going — the user verifies later. |
| "This prod deploy / force-push is probably fine, full send." | The one hard stop is irreducible. Surface irreversible external actions first, always. |
| "User said yolo for a one-line fix; I'll just gate it normally." | Honor the mode requested. Don't silently downgrade an explicit opt-in. |
| "I moved fast, I'll skip the handoff report." | The report **is** the deliverable. Without it, "test later" is impossible. |

## Red Flags

- YOLO fired without an explicit user opt-in
- You turned clarification into a plan-approval or per-slice checkpoint
- You asked about something you could reasonably have assumed (question-spam)
- You stopped and waited for a green test before continuing
- You delivered a partial slice and paused for approval
- You performed an irreversible external action without surfacing it first
- You ended without an assumptions log + test plan

## Verification

Before calling a YOLO run done:

- [ ] User explicitly opted into YOLO; it did not auto-trigger
- [ ] Material ambiguities were resolved by clarifying questions; minor ones by logged assumptions
- [ ] No approval / spec / plan gate blocked progress after clarification
- [ ] The task was driven as far as autonomously possible — whole thing, not a partial slice
- [ ] No verification step blocked progress; any failing check was recorded, not waited on
- [ ] No irreversible external action was taken without first surfacing it
- [ ] Handoff delivered: assumptions log, change summary, test/verification plan, known gaps/risks
