---
name: implement-commit
description: Runs a feature or fix end-to-end IN PLACE on the current branch — spec → plan → build → verify → review — then COMMITS the result locally with the `commit` skill (no push, no PR, no worktree). The lightest terminal rung of the /implement family, where /implement leaves the change uncommitted and only suggests a commit, implement-commit stops at one or more local commits, /implement-worktree pushes a branch, /implement-pr opens a PR. Honors a Jira key / *.atlassian.net URL (intake + report-back, seeding the spec's success criteria from the ticket's acceptance criteria). Use when you want to build something and land it as local commits on the current branch without pushing or opening a PR. Triggers on "implement and commit", "implement-commit", "build it and commit locally", "implement in place then commit". Use ONLY for in-place implement-then-local-commit — to also push in a dedicated worktree use /implement-worktree, to open a PR use /implement-pr, to implement WITHOUT committing use /implement, and to commit already-staged changes without implementing use the `commit` skill.
---

# Implement-Commit

## Overview

Drives a change from idea to a **local commit** in five phases — **spec → plan →
build → verify → review** — working **in place on the current branch** (no
worktree), then commits the verified result with the `commit` skill. It is the
`/implement` lifecycle plus one final step: actually landing the change as one or
more commits instead of merely *suggesting* one.

Where each rung of the family stops:

| Command | Terminal artifact | Worktree? |
|---|---|---|
| `/implement` | uncommitted working-tree changes (suggests a commit) | no |
| **`implement-commit`** | **one or more local commits on the current branch** | **no** |
| `/implement-worktree` | a pushed branch (no PR) | yes |
| `/implement-pr` | an open pull request | yes |

This skill backs the `/implement-commit` command; the command is the thin wrapper
that arms pane auto-close, this skill is the workflow.

## When to Use

- You want to implement a feature, fix, or change **and land it as local
  commits** on the branch you are already on — without pushing or opening a PR.
- You are iterating locally and want verified, reviewed, committed increments you
  will push or PR yourself later.

**Do NOT use when:**

- You want the change **pushed** (in a dedicated worktree) — use
  `/implement-worktree`.
- You want a **pull request** — use `/implement-pr`.
- You want to implement but **not** commit (leave the change in the working tree)
  — use `/implement`.
- You only need to commit **already-staged** changes with no implementation — use
  the `commit` skill directly.
- The change belongs on a fresh branch/worktree rather than the current branch —
  set that up first (`worktree-management`) or use `/implement-worktree`.

## Modifiers

Parse these out of the argument first; whatever remains is the task.

- **Jira key / URL** — a `^[A-Z]+-[0-9]+$` token or a
  `*.atlassian.net/browse/<KEY>` URL turns on Jira **intake + report-back**; the
  ticket's acceptance criteria become the spec's success criteria.

If nothing remains and no Jira key was given, ask what to implement first.

## The Workflow

```
(Jira intake) → Spec → Plan → Build → Verify → Review → Stage + Commit (local)
                 gate    gate                             commit skill, tree clean
```

### Phase 0 — Jira intake (only with a Jira key)

Load `acli`, read the ticket, self-assign, move it to *In Progress*, and pull any
linked Figma design (load `figma`). Carry the acceptance criteria into the spec
as concrete success criteria. (Mirrors `/implement`'s Phase 0.)

### Phases 1–5 — Spec · Plan · Build · Verify · Review

Run the **identical** core flow from `/implement` — its confirm gates after the
spec and after the plan are unconditional, and it always asks open questions
instead of assuming:

1. **Spec** — load `spec-driven-development`; surface assumptions, then a concise
   objective / testable success criteria / boundaries. Confirm before planning.
2. **Plan** — load `planning-and-task-breakdown`; ordered, dependency-aware tasks,
   each S–M with acceptance + a verify step. Confirm before building.
3. **Build** — load `incremental-implementation` and `test-driven-development`
   (and `source-driven-development` for framework specifics); implement each task
   test-first, keeping the tree green. Scope discipline: note, don't fix,
   unrelated issues.
4. **Verify** — run the full suite (tests, build, lint, type-check); confirm every
   success criterion; fix root causes (`debugging-and-error-recovery`) and close
   coverage gaps (`testability-and-coverage`).
5. **Review** — load `code-review-and-quality`; review the whole change as if it
   were someone else's PR; fix anything that wouldn't pass, then re-verify.

### Phase 6 — Stage + commit locally (no push, no PR)

Once the change is built, verified, and reviewed:

1. **Stage the work.** `git add` the change — the `commit` skill commits only what
   is **already staged** and never stages for you. Split genuinely distinct
   concerns into separate atomic commits: stage one concern, commit, repeat (defer
   atomic-commit judgment to `git-workflow-and-versioning`).
2. **Commit.** Load the `commit` skill for each staged group; it writes a
   conventional message and includes the Jira key when the branch name has one.
3. **Confirm a clean tree.** `git status` must show nothing left to commit before
   finishing. **Do not push and do not open a PR** — those are
   `/implement-worktree` / `/implement-pr`.

### Phase 7 — Report back to Jira (only with a Jira key)

Comment a summary on the ticket (what changed, the branch, the commit hash(es),
how it was verified) with `acli`, then propose the next transition, confirming the
exact status name from the project's workflow before running it. Because nothing
is pushed yet, prefer keeping it *In Progress* (or the project's equivalent)
rather than *In Review*.

## Rules

- **In place, current branch.** Never create a worktree or switch branches; the
  commit lands on the branch you are already on.
- **Never push, never open a PR.** The terminal artifact is a local commit.
- **Stage, then delegate to `commit`.** Staging is this skill's job; message
  formatting is the `commit` skill's job. End with a clean working tree.
- **Honor the gates.** Confirm after the spec and after the plan; never skip
  these. Resolve every open question with the `question` tool before advancing —
  do not assume.
- **Scope discipline.** Touch only what the task requires; note unrelated issues
  instead of fixing them.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll push it too, that's convenient." | No. implement-commit stops at a local commit. Pushing is `/implement-worktree`. |
| "I'll open a quick PR since I'm here." | Out of scope — that is `/implement-pr`. |
| "The `commit` skill will stage for me." | It won't — it commits only already-staged files. Stage first. |
| "One giant commit is fine." | Split genuinely distinct concerns into atomic commits before invoking `commit`. |
| "Make a new branch/worktree for this." | This flow is in place on the current branch. Use `/implement-worktree` if you need a fresh branch. |
| "Skip the spec/plan gate, it's obvious." | The confirm gates are unconditional — the cheapest place to catch a wrong assumption. Ask, don't assume. |

## Red Flags

- Running `git push` or `gh pr create` (that is `/implement-worktree` /
  `/implement-pr`, not this).
- Creating a worktree or switching branches.
- Invoking the `commit` skill before staging anything (nothing to commit).
- Leaving the working tree dirty after "finishing".
- Skipping the spec/plan confirm gates, or proceeding past an open question without asking.
- Implementing features not in the spec, or fixing unrelated issues mid-build.

## Verification

- [ ] The change was specced, planned, built, verified, and reviewed (both
      confirm gates honored; open questions asked, not assumed).
- [ ] Work happened **in place** on the current branch — no worktree, no branch
      switch.
- [ ] Everything was staged and committed via the `commit` skill; `git status` is
      clean.
- [ ] Nothing was pushed and no PR was opened.
- [ ] For a Jira key: intake done up front, and a summary comment + proposed
      transition on report-back.
