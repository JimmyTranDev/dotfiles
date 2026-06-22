---
description: Run a feature end-to-end — spec, plan, build, verify, review — fully autonomous, pausing only to ask a clarifying question after the spec or plan when something is genuinely ambiguous
---

Drive **$ARGUMENTS** from idea to merged-quality code in five phases: **spec →
plan → build → verify → review**. Run autonomously end-to-end. The **only**
reason to pause is a clarifying question after the spec or after the plan when
something is genuinely ambiguous and a wrong guess would change the work. With
nothing to clarify, flow straight through to a finished, verified, reviewed
change — no go/no-go gates.

If `$ARGUMENTS` is empty, ask what to implement before starting.

## Phase 1 — Spec

1. Load the `spec-driven-development` skill with the skill tool and follow it.
2. **Surface assumptions first** — list what you're inferring about scope, stack,
   and behavior before writing spec content.
3. Produce a **concise** spec: objective, success criteria (specific and
   testable), scope/boundaries (always / ask-first / never), and open questions.
   Keep it proportional to the task — a small change gets a few lines, not pages.

**Clarify only if needed (after spec).** Scan for genuinely blocking
ambiguities — anything where a wrong assumption would change scope or behavior
and you cannot resolve it from the codebase or context. If any exist, ask them
with the `question` tool (3 concrete proposals each, best first), fold the
answers into the spec, and continue. If the spec is unambiguous, state your key
assumptions and **advance to planning automatically** — no confirmation gate.

## Phase 2 — Plan

1. Load the `planning-and-task-breakdown` skill with the skill tool and follow it.
2. Break the spec into **ordered, dependency-aware tasks**, each sized S–M (no
   task touching more than ~5 files). Every task gets acceptance criteria and a
   verification step (test / build / manual check). Prefer vertical slices.

**Clarify only if needed (after plan).** Same rule: pause only if sequencing,
scope, or approach has a genuine ambiguity whose answer would change the plan.
Ask those with the `question` tool, fold in the answers, then continue.
Otherwise **advance to build automatically** — no confirmation gate.

## Phase 3 — Build (autonomous)

Run without gates — implement every task to completion:

1. Load `incremental-implementation` and `test-driven-development` and follow
   them. For framework/library specifics, load `source-driven-development`.
2. For each task: write the test, implement the smallest slice, run the
   project's tests/build/lint, and keep the tree green before moving on. Use a
   todo list to track task-by-task progress.
3. Touch only what the task requires (scope discipline). Note — don't fix —
   unrelated issues you spot.

**The only reasons to stop the build and ask:** a genuinely blocking ambiguity
that wasn't settled in the spec or plan, or an **irreversible / destructive
action** (deleting data, force-push, prod deploy, schema drops, anything moving
money or sending external comms). Otherwise keep going.

## Phase 4 — Verify

With all tasks built, verify the change as a whole (not just the slices you
touched):

1. Run the **full** suite — tests, build, lint, type-check — and confirm every
   spec success criterion is actually met.
2. If anything fails or behaves unexpectedly, load `debugging-and-error-recovery`
   and fix the **root cause** (not the symptom), then re-run.
3. Confirm new/changed logic is **meaningfully covered**. If code was hard to
   test or coverage is thin, load `testability-and-coverage` and close the gaps.
4. For high-stakes, security-sensitive, or irreversible logic, load
   `doubt-driven-development` for an adversarial pass before it stands.

Don't proceed to review until the suite is green.

## Phase 5 — Review

Load `code-review-and-quality` and review the complete change across every axis
(correctness, design, tests, security, readability) as if it were someone
else's PR. Fix anything that wouldn't pass review, then **re-verify** (Phase 4)
after the fixes.

## Done

Report: the spec summary, any clarifications asked and how they were answered,
the task list with each task's status, the verify results (tests / build / lint
/ coverage), the review findings and how they were resolved, and anything
noted-but-not-touched. If the change is ready to land, suggest committing with
the `commit` skill.
