---
name: parallelization
description: Batches independent tool calls into a single message so they execute at once instead of one at a time, keeping the agent fast without bloating context. Use when you're about to make several tool calls whose inputs don't depend on each other's outputs — reading multiple known files, running independent greps/globs, gathering read-only git status/diff/log together, or running independent verification. Triggers on "in parallel", "at the same time", "run these together", "batch these calls", "speed this up", "stop going one at a time". Use ONLY for batching independent in-session tool calls — to hand open-ended or self-contained work to explore/general Task subagents use `delegation`, for parallel git worktrees use `worktree-management`, and for parallel CI jobs use `ci-cd-and-automation`.
---

# Parallelization

## Overview

An agent that issues independent tool calls one at a time wastes round-trips.
When several calls don't depend on each other, putting them in a **single**
message runs them together — same results, less wall-clock time, no downside.
This skill is the discipline for spotting independence and batching accordingly.
Its sibling `delegation` covers handing work to subagents; this skill is purely
about batching the calls you make yourself.

## When to Use

- You're about to make several tool calls and every argument is known **right
  now** (none waits on another call's output).
- You catch yourself running Read → Read → Read or Grep → Grep sequentially with
  no data dependency between them.
- You want independent read-only inspection at once (e.g. `git status`, `git
  diff`, `git log`).
- You have independent checks or verifications that don't affect each other.

**Do NOT use when:**

- Each step needs the previous step's output — a dependent chain stays
  sequential.
- Two calls would write the same file/resource — serialize or partition first.
- The work is open-ended exploration or a self-contained multi-step unit — that's
  `delegation` (hand it to a subagent), not a batch of direct calls.

## Two Independence Tests

Before batching, both must hold:

1. **Data independence** — does any call need another call's output as an input?
   If yes → keep it sequential.
2. **Write independence** — do two calls write the same file/resource? If yes →
   serialize or split into disjoint scopes.

```
Calls to make
   │
   ├─ Any call needs another's output? ────→ Sequential
   ├─ Two calls write the same target? ────→ Serialize / split scope
   └─ All inputs known now, no write clash ─→ Batch in ONE message
```

## Batch vs. Keep Sequential

**Batch (one message):**

- Reading several known files at once (a component + its test + its types).
- Independent searches: grep `useAuth` and glob `**/*.test.ts` together.
- Read-only git inspection: `git status`, `git diff`, `git log --oneline -10`.
- Independent verifications on targets that don't affect each other.

**Keep sequential (dependent chain):**

- `mkdir foo` THEN `cp x foo/` — the dir must exist first.
- `git add` THEN `git commit` — stage before commit.
- Read a config to discover a path, THEN read that path.
- Any "use the result of A to form B" pattern.

Rule of thumb: if you can write down every call's arguments **now** without
waiting on a result, batch them. If an argument is "whatever A returns," don't.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll read these files one at a time to be safe." | If their paths are all known now, one batched message gives the same result, faster, with no downside. |
| "Parallel is always faster." | Dependent steps run in parallel produce garbage — the second call needed the first's output. Independence is the prerequisite, not speed. |
| "I'll batch these two writes to the same file." | Concurrent writes to one target race and corrupt each other. Serialize, or give each a disjoint scope. |
| "Batching is more effort than just firing calls." | It's the same calls in one message instead of N messages — strictly less overhead, not more. |

## Red Flags

- A run of identical sequential tool calls (Read, Read, Read) with no data
  dependency between them.
- Parallelizing calls where a later call's argument depends on an earlier call's
  result.
- Two batched calls writing the same file or resource.
- Firing calls one message at a time when every argument was already known.

## Verification

- [ ] Every call in a batch shares no data dependency (no call consumes another's
  output).
- [ ] No two calls in a batch write the same file/resource; write scopes are
  disjoint or serialized.
- [ ] Independent reads/searches/inspection were issued in one message, not
  drip-fed sequentially.
- [ ] Dependent steps were deliberately kept sequential.
