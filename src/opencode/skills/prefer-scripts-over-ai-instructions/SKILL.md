---
name: prefer-scripts-over-ai-instructions
description: Decides whether a repeatable agent workflow step should be a committed script or a natural-language instruction, favoring a deterministic script when it is more efficient and reproducible than prose the agent re-derives each run. Use when authoring or reviewing a skill/workflow and a step is deterministic, repeatable, and verifiable (parsing/reshaping data, multi-command sequences, JSON/CLI plumbing, idempotent setup, anything otherwise narrated as fragile step-by-step prose); when a skill keeps re-explaining the same procedure; or when choosing between shipping a scripts/ helper and writing instructions. Triggers on "prefer a script", "script vs instruction", "should this be a script", "codify as a script", "deterministic step", "scriptable", "make it reproducible". Use ONLY for the script-vs-prose medium choice within a workflow step; for SKILL.md authoring mechanics use skill-authoring, for CI pipeline automation use ci-cd-and-automation, and for batching in-session tool calls use parallelization.
---

# Prefer Scripts Over AI Instructions

## Overview

A repeatable workflow step can live in two mediums: a **committed script** the
agent runs, or a **natural-language instruction** the agent re-interprets every
time. Prose is flexible but non-deterministic — the agent re-derives the steps,
drifts between runs, and can silently skip one. A script executes the same way
every time, fails loudly, and is testable. This skill is the discipline for
choosing the right medium **per step**: reach for a script when a step is
deterministic and repeatable, and keep prose for judgment.

It composes with `skill-authoring` (whose §6 "Decide on supporting files" says
add a `scripts/` helper "only when the skill ships real runnable helpers") — this
skill is *how you make that call*. It does not change authoring mechanics; it
decides what a step should be made of.

## When to Use

- Authoring or reviewing a skill/workflow and a step is deterministic,
  repeatable, and verifiable.
- You catch yourself writing fragile step-by-step prose ("run X, copy the id,
  paste it into Y, then run Z") that has one correct execution.
- A skill keeps **re-explaining the same procedure** every run — a sign it should
  be codified once.
- You're deciding between shipping a `scripts/` helper and writing instructions.
- The step does data plumbing: parsing/reshaping JSON, string surgery,
  multi-command sequences, idempotent setup, environment probing.

**Do NOT use when:**

- The step needs **judgment, taste, or context** (naming, prose, design
  trade-offs, reviewing intent) — that is exactly what instructions are for; a
  script can't decide it.
- The action runs **once** and never repeats — a script is overhead, not
  leverage (skill-authoring: "a one-off belongs in a command or direct action").
- You're authoring the surrounding `SKILL.md` structure/frontmatter → that's
  `skill-authoring`.
- You're wiring a **CI/CD pipeline** → `ci-cd-and-automation`.
- You're batching independent **in-session tool calls** → `parallelization`.

## The Decision

Ask these in order; the first "no" ends the descent at the medium it names.

```
A workflow step
   │
   ├─ Is it deterministic? (same inputs -> same steps, no judgment) ─ no ─→ INSTRUCTION
   │        │ yes
   ├─ Does it repeat / run more than once? ───────────────────────── no ─→ INSTRUCTION (one-off)
   │        │ yes
   ├─ Is the outcome verifiable? (exit code, diff, parseable output) ─ no ─→ INSTRUCTION, but add a check
   │        │ yes
   ├─ Is it more than a single trivial command? ──────────────────── no ─→ INLINE COMMAND in prose
   │        │ yes
   └────────────────────────────────────────────────────────────────────→ SCRIPT (commit it, reference it)
```

Two independent signals both push toward a script:

1. **Determinism** — is there exactly one correct execution, or does it need
   the agent's judgment? One correct execution → script.
2. **Repetition** — does the same procedure recur across runs/skills? Recurs →
   script (write once, run many). A genuinely single-use step stays prose.

## Script-Worthy vs Instruction-Worthy

**Make it a script (commit it, then tell the agent to run it):**

- Parsing or reshaping structured data (JSON/CSV/XML), `jq`/`sed` pipelines.
- Multi-step sequences with a strict order where a skipped step corrupts state.
- Idempotent setup / environment probing (detect a lockfile, resolve a repo
  root, pick a base branch).
- Anything you'd otherwise write as brittle "do this, then copy that, then…"
  prose with one correct path.
- A procedure already **duplicated** across skills or re-explained every run.
- Work that must be **identical and auditable** every time (the reason `acli`
  and `todoist-task-management` route through CLIs/scripts to stay "scriptable,
  JSON-parseable, and consistent").

**Keep it an instruction (prose in the SKILL.md):**

- Decisions that need judgment: naming, wording, architecture, prioritization.
- Reviewing or interpreting output a human/agent must reason about.
- Steps whose "correct" answer depends on unpredictable context.
- Genuinely one-off actions.
- The thin glue that says *when* and *why* to run the script (prose still frames
  every script — you narrate intent, the script executes mechanics).

## Worked Examples

- **Reshape a Jira API response into a branch name** → deterministic, repeated,
  verifiable → **script** (`view --json | jq -r '.fields.summary'` wrapped in a
  helper), not five lines of "copy the summary, lowercase it, replace spaces…".
- **Decide the branch's *type* (feat/fix/chore)** → needs judgment about the
  change → **instruction**.
- **Detect the package manager from a lockfile and install** → deterministic,
  recurs in many skills → **script**.
- **Write the PR description prose** → taste/context → **instruction**.
- **`git rev-parse --is-inside-work-tree`** → single trivial command →
  **inline command**, no script file needed.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Prose is more flexible, I'll just describe the steps." | Flexibility is the problem for a deterministic step — the agent re-derives it and drifts. One correct path deserves one script. |
| "Writing a script is more work than writing instructions." | For a step that runs many times, the script is written once and run reliably forever; prose is re-interpreted (and re-broken) every run. |
| "The agent is smart enough to follow the steps each time." | Non-determinism isn't about intelligence — identical prose yields different executions. Scripts remove the variance and fail loudly. |
| "I'll inline this 12-line pipeline in the SKILL.md." | Long mechanical sequences belong in a committed, testable `scripts/` helper the prose invokes — not buried in instructions. |
| "Everything should be a script, then." | No. Judgment, taste, and one-off steps are worse as scripts — a script can't make a design decision. Medium follows the step's nature. |
| "It's deterministic, so script it" (but it runs once). | Determinism alone isn't enough; a single-use step is overhead as a script. Both determinism AND repetition point to a script. |

## Red Flags

- A SKILL.md step reads "run X, take the output, then run Y with it, then Z" for
  a single correct path — that's a script written as prose.
- The same procedure is copy-pasted or re-explained across multiple skills.
- Instructions that reshape JSON/CSV or build strings by hand in prose.
- A `scripts/` helper created for a step that actually needs judgment (a script
  that just wraps a decision the agent should make).
- A one-off action turned into a committed script "for reuse" that never comes.
- Turning *every* instruction into a script, erasing the judgment steps prose
  exists to carry.

## Verification

- [ ] Each deterministic, repeated, verifiable step is a committed script (or a
  single inline command), not multi-line brittle prose.
- [ ] Each judgment/taste/one-off step is an instruction, not a script.
- [ ] Any shipped `scripts/` helper corresponds to a real, repeatable,
  deterministic procedure (per `skill-authoring` §6) — no empty or
  judgment-wrapping scripts.
- [ ] Prose that remains explains *when/why* to run a script, not the mechanical
  steps the script already encodes.
- [ ] The choice was made per step against the decision flowchart, not by
  defaulting to prose (or to scripting everything).
