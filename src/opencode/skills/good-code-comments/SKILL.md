---
name: good-code-comments
description: Writes and reviews high-signal code comments that explain intent (the *why*) instead of restating the code (the *what*), and standardizes the four annotation markers TODO:, FIX:, HACK:, and NOTE:. Use when writing, reviewing, or cleaning up code comments; when deciding whether a comment is worth keeping; when leaving or triaging a TODO:, FIX: (a.k.a. FIXME), HACK:, or NOTE:; or when a comment merely echoes the code, has gone stale, or explains badly-named code that should be renamed instead. Triggers on "good code comments", "comment this", "add comments", "why not what", "TODO/FIX/HACK/NOTE", "comment rot", "FIXME". Do NOT use for external API/reference docs, doc-comment contracts, ADRs, or README/markdown files — that is documentation-and-adrs.
---

# Good Code Comments

## Overview

Comments communicate *intent* that the code itself cannot express. The best comment is often a better name or a clearer structure — but when code genuinely can't carry the meaning (a non-obvious *why*, a trade-off, a constraint, a gotcha), a precise comment is essential. This skill keeps comments high-signal and standardizes four annotation markers — `TODO:`, `FIX:`, `HACK:`, `NOTE:` — so deferred and risky work stays greppable and actionable.

## When to Use

- Writing a comment while implementing, or about to leave a marker.
- Reviewing a diff where comments restate the code, have gone stale, or are missing on genuinely non-obvious logic.
- Cleaning up or triaging existing markers in a file.
- Deciding whether a comment should exist at all.

**Do NOT use when:**

- Authoring external API/reference docs, doc-comments as a public contract, ADRs, or README/markdown — use `documentation-and-adrs`.
- The right fix is to rename a variable or function — prefer self-documenting code over a comment (see Principle 1).

## Principles

### 1. Prefer self-documenting code; comment only the gap

Good names and small functions remove the need for most comments. Reach for a comment only when the code cannot carry the meaning. A comment that restates the code is noise — delete it, or replace the code with a clearer name.

```ts
// BAD: the comment just re-reads the code
// loop over the users and send each one an email
for (const u of users) sendEmail(u);

// BETTER: no comment needed — the name says it
notifyUsers(users);
```

### 2. Explain *why*, not *what*

The code already says *what* it does. A comment earns its place by capturing intent: the reason, the trade-off, the constraint, the thing that bit someone last time.

```ts
// BAD (what): i++
i++; // increment i

// GOOD (why): the non-obvious reason
// Stripe rounds half-up; mirror it here so our refund total can't drift
// a cent from theirs.
total = roundHalfUp(total);
```

### 3. Keep comments next to — and true to — the code

A comment that has drifted out of sync is worse than none, because it actively misleads. Put the comment immediately above what it describes, and update or delete it in the *same* change that changes the code. Comment rot is a bug.

### 4. Make deferred and risky work greppable with markers

For work you are deferring or debt you are taking on, leave a standard marker (next section) instead of buried prose. Markers are searchable, surfaced by tooling (todo-tree, ESLint `no-warning-comments`), and easy to triage.

## Marker Conventions

**Format:** `<MARKER>: <specific, actionable message> (<ticket/owner> — optional)`. Always UPPERCASE, always followed by a colon and one space, on its own comment line directly above the relevant code.

| Marker | Means | Use when | Don't use for |
|---|---|---|---|
| `TODO:` | Planned, intentional work that is fine to ship without | You deliberately deferred something and want it tracked | A real defect — use `FIX:` |
| `FIX:` | A known defect / incorrect behavior that needs fixing | Behavior is wrong but you can't fix it right now | Cleanup with no defect — use `TODO:`/`HACK:` |
| `HACK:` | A deliberate workaround/kludge that works but isn't the right way | You worked around a constraint (upstream bug, deadline) and want the debt visible | Code you're actually happy with |
| `NOTE:` | Important context the reader needs but wouldn't expect | A non-obvious constraint, gotcha, or assumption | Restating what the code plainly does |

```ts
// TODO: paginate once the org list can exceed ~200 entries (BW-1234)
// FIX: race condition when two tabs refresh the token at the same time
// HACK: poll because the vendor webhook is unreliable; remove when CT-77 ships
// NOTE: amounts are in minor units (øre) — the API rejects decimals
```

**Conventions:**

- Be specific and actionable. `// TODO: fix this` helps no one — say *what*, and ideally *when* or under what condition.
- Attach a ticket/issue when one exists; attach an owner for shared code.
- A marker is not a substitute for filing the real ticket when the work matters.
- `FIX:` and `HACK:` are technical debt — surface them in review, don't bury them.

**Aliases you may encounter:** many codebases and tools also recognize `FIXME` (treat as `FIX:`), `XXX` (severe — treat as `FIX:`/`HACK:`), `WARNING`/`WARN`, and `REVIEW`. Normalize to the four canonical markers when writing new comments; don't churn existing ones solely to rename them.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "More comments = more readable." | Noise comments bury the few that matter, and every comment is a maintenance liability. Signal, not volume. |
| "I'll comment what the code does so it's clear." | If the code needs a *what*-comment, rename it instead. Comment the *why*. |
| "I'll leave a bare `TODO` and remember the details." | You won't, and neither will the next reader. Make it specific and ticket it. |
| "`FIXME` vs `FIX` vs `XXX` — doesn't matter." | Inconsistent markers can't be grepped or tooled. Normalize to the four. |
| "The comment is slightly out of date but close enough." | A wrong comment actively misleads. Fix it in the same change, or delete it. |
| "`HACK` is embarrassing; I'll leave it unlabeled." | Hidden debt never gets paid. Label it so review and future-you can find it. |

## Red Flags

- Comments that paraphrase the line below them (`// loop over users` above the loop).
- A comment that a better name would make unnecessary.
- Bare or vague markers: `// TODO`, `// FIX: broken`.
- Lowercase or non-colon markers (`//todo`, `// Fixme`) that tooling won't catch.
- Commented-out code left "just in case" — delete it; that's what git is for.
- A comment that contradicts the code it sits on (rot).
- `TODO:` used to mark an actual bug, or `NOTE:` used to restate the code.

## Verification

- [ ] Every new comment explains *why*/intent or is a standard marker — none merely restate the code.
- [ ] Any comment a better name would obviate has been replaced by the rename.
- [ ] All markers are one of `TODO:`/`FIX:`/`HACK:`/`NOTE:`, UPPERCASE, colon-terminated, with a specific message.
- [ ] `TODO:`/`FIX:` items that matter reference a ticket or issue.
- [ ] No commented-out code, and no stale or contradictory comments, remain in the diff.
