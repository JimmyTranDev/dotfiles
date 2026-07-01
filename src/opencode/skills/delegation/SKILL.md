---
name: delegation
description: Hands self-contained or open-ended work to Task-tool subagents (explore/general) that run with their own fresh context and return a single summary, both parallelizing work and protecting the main context window. Use when an open-ended search would bloat context ("how does X work?", "where is Y handled?"), when a self-contained multi-step unit can be fully described up front, when several such units can run at once (concurrent fan-out with disjoint write scopes), or when deciding delegate-vs-do-it-directly. Triggers on "delegate", "subagent", "fan out", "explore agent", "general agent", "spawn an agent", "too much context". Use ONLY for Task-subagent delegation — to batch independent in-session tool calls you make yourself use `parallelization`, for parallel git worktrees use `worktree-management`, and for parallel CI jobs use `ci-cd-and-automation`.
---

# Delegation

## Overview

Subagents launched with the `Task` tool run with **their own fresh context** and
return a single summary message. That summary is the only thing that lands in
your context — so delegation both parallelizes work and *protects* your context
window from dead-end reads. Its sibling `parallelization` covers batching the
tool calls you make yourself; this skill covers handing work off entirely.

## When to Use

- An open-ended question ("how does X work?", "where is Y handled?", "find all
  callers of Z") would otherwise pull many files into your context.
- A self-contained, multi-step unit of work can be described completely up front.
- Several such independent units exist and can run at once.
- You're deciding whether to delegate at all versus doing it directly.

**Do NOT use when (do it directly instead):**

- You already know the exact path/symbol — Read or Grep it yourself; a subagent
  is slower and costlier.
- The task is 1–2 trivial tool calls.
- The work needs tight, iterative back-and-forth with the user, or context only
  you hold and can't hand off.
- The calls are independent and you can simply batch them yourself — that's
  `parallelization`.

## Pick the Agent

- **`explore`** — fast codebase search and questions ("where are API errors
  handled?", "find all callers of `X`"). Specify thoroughness: `quick`, `medium`,
  or `very thorough`. Use it instead of running many Grep/Glob/Read calls
  yourself for open-ended questions.
- **`general`** — a self-contained, multi-step unit of work (research across many
  files, or an isolated task with clear boundaries).

Reads and research delegate freely; writes must be scoped (see fan-out).

## Concurrent Fan-out

To run independent units at once, issue **multiple `Task` calls in one message**.
They execute concurrently; collect their summaries as they return.

**Safety rules:**

- **Reads/research fan out freely** — no conflicts.
- **Writes must have disjoint scopes** — give each subagent a non-overlapping set
  of files/modules. Never have two agents edit the same file.
- **No cross-dependencies** — if unit B needs unit A's output, they're a
  sequence, not a fan-out.
- **Reconcile after** — you integrate and verify the results; a conflict means
  the scopes weren't actually disjoint.

Resume a subagent's session with its returned `task_id` (instead of starting
fresh) when continuing the same line of work.

## Writing a Delegation Prompt

A subagent can't ask follow-ups — it gets one shot. Give it everything:

- **Context & goal** — what you're doing and why, with the concrete starting
  points (paths, symbols) you already know.
- **Exact deliverable** — state precisely what the final message must contain
  ("return the file:line of each handler and a one-line description").
- **Research vs. write** — say explicitly whether to change code or only
  investigate.
- **Boundaries** — what's in scope and what NOT to touch (critical for write
  fan-out).
- **How to verify** — the test/build/lint command that proves the work, when
  applicable.

A vague prompt yields a wasted run. The detail you skip is the detail it guesses
wrong.

## Relay the Result

A subagent's output is **not shown to the user** — you must relay its findings,
not just report "done". Integrate the result and surface what it found.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "A subagent is overkill, I'll just grep around myself." | Open-ended exploration spends main-context tokens on dozens of dead-end reads. `explore` returns just the answer. |
| "I'll spin up a subagent to read this one known file." | If you know the path, Read it directly — a subagent is slower and costlier for a needle lookup. |
| "I'll fan out and let the agents sort out the files." | Overlapping writes corrupt each other. Partition into disjoint scopes before fanning out, or serialize. |
| "I'll keep the delegation prompt short and clarify later." | Subagents can't ask. A thin prompt yields a thin or wrong result you then redo. |
| "I'll just say the subagent did its job." | Its output isn't visible to the user. Relay the actual findings. |

## Red Flags

- Dozens of exploratory Grep/Glob/Read calls in the main thread for one
  open-ended question instead of an `explore` subagent.
- Spinning up a subagent to read a single known file or run one trivial call.
- Two concurrent subagents given overlapping write scopes.
- A delegation prompt with no stated deliverable or no scope boundaries.
- Reporting a subagent's result as "done" without relaying what it found.

## Verification

- [ ] Open-ended exploration was delegated to `explore` (not run as many
  main-thread searches); needle lookups were done directly.
- [ ] Each delegation prompt states the goal, the exact deliverable,
  research-vs-write, scope boundaries, and a verification command where relevant.
- [ ] Concurrent write-capable subagents have disjoint file/module scopes; reads
  may overlap freely.
- [ ] Subagent results were integrated and their findings relayed to the user
  (not just "done").
