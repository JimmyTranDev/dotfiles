---
description: Produce a spec and an ordered task plan for $ARGUMENTS, then stop — no build, verify, or review. Hands back the spec + plan for review.
---

Take **$ARGUMENTS** from idea to a reviewed **spec** and an ordered **task
plan**, then **stop**. This command deliberately does **not** build, verify, or
review code — its only deliverables are the spec and the plan.

If `$ARGUMENTS` is empty, ask what to spec and plan before starting.

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
- **Stop here** — hand back the spec without planning.

Do not start planning until this gate returns "Proceed".

## Phase 2 — Plan

1. Load the `planning-and-task-breakdown` skill with the skill tool and follow it.
2. Break the spec into **ordered, dependency-aware tasks**, each sized S–M (no
   task touching more than ~5 files). Every task gets acceptance criteria and a
   verification step (test / build / manual check). Prefer vertical slices.
3. Surface the critical path, any parallelizable tracks, and the riskiest tasks.

## Done — stop here

**Do not build, verify, or review.** The spec and the plan are the whole
deliverable. Present:

- the **spec** — objective, success criteria, scope/boundaries, open questions;
- the **task plan** — ordered tasks, each with acceptance criteria and a
  verification step, plus the critical path and risky tasks;
- any clarifications asked and how they were answered, plus key assumptions.

Then hand off without touching code: to implement the plan, suggest running
`/implement` (gated) or `/implement yolo` (autonomous) on the same feature, or
loading the `incremental-implementation` + `test-driven-development` skills
directly.
