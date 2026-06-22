---
description: Run a feature end-to-end — spec, plan, build, verify, review — auto-advancing with a quick confirm after the spec and after the plan
---

Drive **$ARGUMENTS** from idea to merged-quality code in five phases: **spec →
plan → build → verify → review**. Advance automatically, pausing only for a
quick go/no-go after the spec and after the plan (wrong assumptions caught there
are the cheapest to fix).

If `$ARGUMENTS` is empty, ask what to implement before starting.

## Phase 1 — Spec

1. Load the `spec-driven-development` skill with the skill tool and follow it.
2. **Surface assumptions first** — list what you're inferring about scope, stack,
   and behavior before writing spec content.
3. Produce a **concise** spec: objective, success criteria (specific and
   testable), scope/boundaries (always / ask-first / never), and open questions.
   Keep it proportional to the task — a small change gets a few lines, not pages.

**Confirm gate (after spec).** Present the spec + assumptions, then use the
`question` tool to ask how to proceed, with exactly these three options:

- **Proceed to planning (Recommended)** — the spec is right; continue.
- **Revise the spec first** — adjust assumptions/scope, then re-confirm.
- **Stop here** — hand back the spec without planning or building.

Do not start planning until this gate returns "Proceed".

## Phase 2 — Plan

1. Load the `planning-and-task-breakdown` skill with the skill tool and follow it.
2. Break the spec into **ordered, dependency-aware tasks**, each sized S–M (no
   task touching more than ~5 files). Every task gets acceptance criteria and a
   verification step (test / build / manual check). Prefer vertical slices.

**Confirm gate (after plan).** Present the task list, then use the `question`
tool with exactly these three options:

- **Proceed to build (Recommended)** — the plan is right; start implementing.
- **Revise the plan first** — re-slice/re-order, then re-confirm.
- **Stop here** — hand back the spec + plan without building.

Do not write implementation code until this gate returns "Proceed".

## Phase 3 — Build (autonomous)

Now run without further gates — implement every task to completion:

1. Load `incremental-implementation` and `test-driven-development` and follow
   them. For framework/library specifics, load `source-driven-development`.
2. For each task: write the test, implement the smallest slice, run the
   project's tests/build/lint, and keep the tree green before moving on. Use a
   todo list to track task-by-task progress.
3. Touch only what the task requires (scope discipline). Note — don't fix —
   unrelated issues you spot.

**The only reasons to stop the build and ask:** a genuinely blocking ambiguity
that wasn't settled in the spec, or an **irreversible / destructive action**
(deleting data, force-push, prod deploy, schema drops, anything moving money or
sending external comms). Otherwise keep going.

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

Report: the spec summary, the task list with each task's status, the verify
results (tests / build / lint / coverage), the review findings and how they were
resolved, and anything noted-but-not-touched. If the change is ready to land,
suggest committing with the `commit` skill.
