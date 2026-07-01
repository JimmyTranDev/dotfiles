---
name: parallelization-and-delegation
description: Parallelizes independent work and delegates to subagents to finish faster and conserve the main context window. Use when a task contains multiple independent steps that could run at once (reading several files, running independent searches or checks, gathering git status/diff/log), when open-ended codebase exploration would bloat context, when you catch yourself issuing tool calls one at a time that have no dependency between them, or when deciding whether to batch tool calls, fan work out across Task-tool subagents (explore/general), or keep steps sequential because each feeds the next. Triggers on "parallelize", "in parallel", "at the same time", "delegate", "subagent", "fan out", "run these together", "speed this up", "too much context". Use ONLY for in-session tool-call batching and Task-subagent delegation — for git-worktree parallelism use worktree-management, for CI job parallelism use ci-cd-and-automation.
---

# Parallelization and Delegation

## Overview

Two levers make an agent faster and keep its context clean: **parallelization**
(issue independent tool calls together in one message instead of one at a time)
and **delegation** (hand self-contained or open-ended work to `Task`-tool
subagents that run with their own fresh context). This skill is the decision
discipline for when to use each — and, just as important, when not to.

## When to Use

- You're about to make several tool calls whose inputs don't depend on each
  other's outputs.
- An open-ended search ("how does X work?", "where is Y handled?") would pull a
  lot of files into the main context.
- You have multiple independent units of work that could progress at once.
- You catch yourself running Read → Read → Read or Grep → Grep sequentially with
  no dependency between them.

**Do NOT use when:**

- Each step needs the previous step's output (a dependent chain) — keep it
  sequential.
- You already know the exact file/symbol — Read/Grep it directly; don't spin up
  a subagent.
- The work needs tight, iterative back-and-forth with the user.
- Parallel writes would touch the same files (race/conflict) — serialize or
  partition scopes first.

This skill is about in-session execution. For parallel git worktrees use
`worktree-management`; for CI job parallelism use `ci-cd-and-automation`.

## Decision Flow

```
Work to do
   │
   ├─ Single dependent chain (each step feeds the next)? ──→ Sequential tool calls
   │
   ├─ Several INDEPENDENT calls, all inputs known now? ────→ Batch in ONE message (parallel)
   │
   ├─ Open-ended exploration / would bloat context? ───────→ Delegate to `explore` subagent
   │
   ├─ Self-contained multi-step unit of work? ─────────────→ Delegate to `general` subagent
   │
   └─ Many independent units at once? ─────────────────────→ Fan out: multiple Task calls in one message
                                                              (partition writes by disjoint scope)
```

Two independence tests before parallelizing or fanning out:

1. **Data independence** — does any call need another's output as input? If yes
   → sequential.
2. **Write independence** — do two calls write the same file/resource? If yes →
   serialize or split scopes.

## Parallelization — batch independent tool calls

Put multiple tool calls in a **single** message when they're independent. They
execute together instead of round-tripping one at a time.

**Good batches:**

- Reading several known files at once (e.g., a component + its test + its types).
- Independent searches: grep for `useAuth` and glob `**/*.test.ts` together.
- Read-only git inspection: `git status`, `git diff`, `git log --oneline -10` in
  one go.
- Independent verification on targets that don't affect each other.

**Keep sequential when dependent:**

- `mkdir foo` THEN `cp x foo/` (the dir must exist first).
- `git add` THEN `git commit` (stage before commit).
- Read a config to discover a path, THEN read that path.
- Any "use the result of A to form B" pattern.

Rule of thumb: if you can write down every call's arguments **right now** without
waiting on a result, batch them. If an argument is "whatever step A returns,"
don't.

## Delegation — hand work to subagents

Subagents run with **their own fresh context** and return a single summary
message. That summary is the only thing that lands in your context — so
delegation both parallelizes work and *protects* your context window. The result
is **not shown to the user**; you must relay it.

**Pick the agent:**

- **`explore`** — fast codebase search and questions ("where are API errors
  handled?", "find all callers of `X`"). Specify thoroughness: `quick`,
  `medium`, or `very thorough`. Use it instead of running many Grep/Glob/Read
  calls yourself for open-ended questions.
- **`general`** — a self-contained, multi-step unit of work (research across many
  files, or an isolated task with clear boundaries).

**Delegate when:**

- The question is open-ended and would otherwise pull many files into context.
- The unit of work is self-contained and you can describe it completely up front.
- Several such units exist and can run concurrently.

**Do it directly (no subagent) when:**

- You know the exact path/symbol — Read or Grep is faster and cheaper.
- The task is 1–2 trivial tool calls.
- It needs ongoing user interaction or context only you hold and can't easily
  hand off.

## Concurrent fan-out

To run independent units at the same time, issue **multiple `Task` calls in one
message**. They execute concurrently; collect their summaries as they return.

**Safety rules for fan-out:**

- **Reads/research fan out freely** — no conflicts.
- **Writes must have disjoint scopes** — give each subagent a non-overlapping set
  of files/modules. Never have two agents edit the same file.
- **No cross-dependencies** — if unit B needs unit A's output, they're a
  sequence, not a fan-out.
- **Reconcile after** — when parallel units finish, you integrate and verify; a
  conflict means the scopes weren't actually disjoint.

Resume a subagent's session with its returned `task_id` (instead of starting
fresh) when you need to continue the same line of work.

## Writing a delegation prompt

A subagent can't ask follow-ups — it gets one shot. Give it everything:

- **Context & goal** — what you're doing and why, with the concrete starting
  points (paths, symbols) you already know.
- **Exact deliverable** — state precisely what the final message must contain
  (e.g., "return the file:line of each handler and a one-line description").
- **Research vs. write** — say explicitly whether to change code or only
  investigate.
- **Boundaries** — what's in scope and what NOT to touch (critical for write
  fan-out).
- **How to verify** — the test/build/lint command that proves the work, when
  applicable.

A vague prompt yields a wasted run. The detail you skip is the detail it guesses
wrong.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll read these files one at a time to be safe." | If their paths are all known now, reading them in one batched message gives the same result, faster, with no downside. |
| "A subagent is overkill, I'll just grep around myself." | Open-ended exploration spends main-context tokens on dozens of dead-end reads. `explore` returns just the answer. |
| "I'll fan out and let the agents sort out the files." | Overlapping writes corrupt each other. Partition into disjoint scopes before fanning out, or serialize. |
| "Parallel is always faster." | Dependent steps, run in parallel, produce garbage — the second call needed the first's output. Independence is the prerequisite, not speed. |
| "I'll keep the delegation prompt short and clarify later." | Subagents can't ask. A thin prompt yields a thin or wrong result you then redo. |
| "I'll just say the subagent did its job." | Its output isn't visible to the user. Relay the actual findings, not "done". |

## Red Flags

- A run of identical sequential tool calls (Read, Read, Read) with no data
  dependency between them.
- Dozens of exploratory Grep/Glob/Read calls in the main thread for one
  open-ended question instead of an `explore` subagent.
- Two concurrent subagents given overlapping file scopes.
- Parallelizing calls where a later call's arguments depend on an earlier call's
  result.
- A delegation prompt with no stated deliverable or no scope boundaries.
- Reporting a subagent's result as "done" without relaying what it found.
- Spinning up a subagent to read a single known file.

## Verification

- [ ] Independent tool calls in a batch share no data dependency (no call
  consumes another's output).
- [ ] Concurrent write-capable subagents have disjoint file/module scopes; reads
  may overlap freely.
- [ ] Open-ended exploration was delegated to `explore` (not run as many
  main-thread searches); needle lookups were done directly.
- [ ] Each delegation prompt states the goal, the exact deliverable,
  research-vs-write, scope boundaries, and a verification command where relevant.
- [ ] Subagent results were integrated and their findings relayed to the user
  (not just "done").
- [ ] Dependent steps remained sequential.
