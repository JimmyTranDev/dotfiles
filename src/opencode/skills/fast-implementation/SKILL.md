---
name: fast-implementation
description: Executes small, well-understood, low-risk changes on a fast path — skipping spec/plan/TDD ceremony while keeping a minimal safety net (build and tests still pass). Use when the task is a trivial fix, one-liner, config tweak, copy/string change, dependency bump, or other clearly-scoped single-concern edit and the user signals urgency ("just", "quick", "quickly", "simple", "small change", "fast", "minor tweak"). Do NOT use when the change is multi-file/large, touches auth, security, data, money, or public contracts, is irreversible, or the requirements are unclear — route to the heavier lifecycle skills instead.
---

# Fast Implementation

## Overview

Most changes do not need a spec, a task breakdown, and a red-green TDD loop. When a task is small, the mechanism is obvious, and the blast radius is tiny, that ceremony is pure overhead. This skill is the **express lane**: a qualifying gate that proves a task is safe to fast-track, followed by a tight execute-and-verify loop. The gate is what keeps "fast" from becoming "reckless" — anything that fails it gets routed to the proper heavyweight skill.

## When to Use

Use when **every** gate condition below holds:

- Single concern, roughly ≤ 2 files and ≤ 50 lines
- You already know exactly what to change — no design or research needed
- Low blast radius: reversible, no schema/contract/auth/security/payment impact
- A fast check (existing test, type-check, build, or obvious manual check) can prove it
- Requirements are unambiguous

Typical fits: typo/copy fixes, a config or constant value change, a dependency bump, a small null-check or guard, renaming a local variable, adding a log line, a one-line bug fix with an obvious cause.

**Do NOT use when:**

- The change spans many files or is large → `incremental-implementation`
- Requirements are vague or the "what" is unclear → `interview-me` / `spec-driven-development`
- The cause is unknown or behavior is surprising → `debugging-and-error-recovery`
- It touches auth, untrusted input, secrets, or data integrity → `security-and-hardening`
- It changes a public API or module boundary → `api-and-interface-design`
- It is irreversible or production-critical → `doubt-driven-development`

This skill never *lowers* the safety bar — it only removes ceremony that a small task does not need.

## The Workflow

```
Task arrives
    │
    ▼
┌─────────────────────────────┐
│  GATE: all 5 conditions yes? │
└─────────────────────────────┘
    │                 │
   yes                no ──→ route to the right skill (see table) ──→ STOP
    │
    ▼
1. One-line plan + surface any assumption
2. Make the edit directly (batch related edits, read in parallel)
3. Run the NARROWEST check that proves it
    │
    ▼
  Passes? ── no ──→ this wasn't fast-path; switch to
    │                debugging-and-error-recovery
   yes
    ▼
  Report concisely. Done.
```

### 1. Qualify (the gate)

Run the five conditions in **When to Use**. If **any** is "no", stop and route — do not negotiate with yourself. Fast path is all-or-nothing.

| Gate failure | Route to |
|---|---|
| Large / multi-file | `incremental-implementation` |
| Unclear requirements | `interview-me` → `spec-driven-development` |
| Unknown cause | `debugging-and-error-recovery` |
| Security / untrusted input | `security-and-hardening` |
| Public API / contract change | `api-and-interface-design` |
| Irreversible / high-stakes | `doubt-driven-development` |

### 2. State the one-line plan

One sentence, plus any assumption you are making. Keep it terse — this is a gate against silent wrong guesses, not a planning document.

> "Fixing the off-by-one in `paginate()` at api/list.ts:42 — assuming pages are 1-indexed per the existing callers."

### 3. Execute directly

Make the change in as few steps as possible. Batch related edits, read needed files in parallel, and avoid unrelated cleanup (scope discipline still applies). No slicing, no scaffolding, no new abstractions for a one-off.

### 4. Verify (non-negotiable)

Run the **narrowest** check that proves the change and proves nothing broke — a single targeted test, a type-check, or a focused build. Speed comes from a *small* safety net, never from *no* safety net. If verification reveals the task was bigger or buggier than it looked, the fast path is over: switch to `debugging-and-error-recovery` or `incremental-implementation`.

## Common Rationalizations

This skill's danger is the inverse of the others: "fast" becomes an excuse to cut real corners. These thoughts mean you should be *leaving* the fast path, not staying on it.

| Rationalization | Reality |
|---|---|
| "It's basically small, I'll force it through the gate." | The gate is all-or-nothing. One "no" means route. Forcing it is how a 50-line fix becomes a 3-hour outage. |
| "It's fast, so I'll skip the verification." | Fast path = *small* safety net, not *no* safety net. An unverified change is a guess, not an implementation. |
| "I'm not sure of the cause but the fix looks right." | Unknown cause fails the gate. Guess-fixes belong in `debugging-and-error-recovery`. |
| "While I'm here, I'll also tidy this nearby code." | Scope creep breaks the "single concern" condition and the change is no longer fast-path. Note it, don't do it. |
| "It touches auth but it's a tiny change." | Security blast radius is never small. Route to `security-and-hardening`. |
| "Requirements are a little fuzzy but I'll fill the gaps." | Ambiguity fails the gate. Silent assumptions are the top failure mode — clarify first. |

## Red Flags

- You argued yourself past a "no" on the gate
- You skipped verification "because it's trivial"
- The diff grew past ~2 files / ~50 lines mid-task and you kept going on the fast path
- You started researching how something works (fast path means you already knew)
- "Quick fix" to auth, payments, migrations, or untrusted-input handling
- Unrelated cleanup riding along with the change
- You're fixing a symptom whose cause you can't name

## Verification

Before calling a fast-path task done:

- [ ] All five gate conditions genuinely held (or the task was routed elsewhere)
- [ ] The change is a single concern and within scope
- [ ] A targeted check passed (test / type-check / build) — with evidence, not "looks right"
- [ ] Nothing adjacent was modified or "cleaned up"
- [ ] If anything broke the gate mid-task, control was handed to the appropriate heavier skill
