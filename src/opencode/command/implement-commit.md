---
description: Implement a feature or Jira ticket end-to-end IN PLACE on the current branch — spec, plan, build, verify, review — then commit the result locally (no push, no PR, no worktree); always asks open questions instead of assuming
---

Implement **$ARGUMENTS** end-to-end **in place on the current branch**, then land
it as one or more **local commits** — **no push and no pull request**. This is the
`/implement` flow finished with a commit: the lightest terminal rung of the family
(`/implement-worktree` pushes a branch, `/implement-pr` opens a PR).

Load the `implement-commit` skill with the skill tool and follow it; the phases
below are that workflow.

## Modifiers — parse `$ARGUMENTS` first

Read the same optional Jira modifier as `/implement`, then treat the remainder as
the task:

- **Jira key / URL** — `^[A-Z]+-[0-9]+$` or `*.atlassian.net/browse/<KEY>` turns
  on Jira intake + report-back and seeds the spec's success criteria from the
  ticket's acceptance criteria.

If nothing remains and no Jira key was given, ask what to implement first.

## Phase 0 — In place on the current branch (+ Jira intake)

This flow works **in place on the current branch** — it does **not** create a
worktree or switch branches. Confirm you are on the intended branch
(`git branch --show-current`) before writing any code; every commit lands there.

If a Jira key was passed, now run **`/implement`'s Phase 0 — Jira intake** (read
the ticket + self-assign + move to *In Progress* + pull any linked Figma), and
carry the acceptance criteria into the spec as concrete success criteria.

## Phases 1–5 — Spec · Plan · Build · Verify · Review

Run the **identical** core flow from `/implement` (Phases 1–5) — including its
confirm gates after the spec and after the plan, and its rule to always ask open
questions instead of assuming — plus any Jira acceptance criteria.

## Phase 6 — Stop at a local commit (no push, no PR)

Once the change is built, verified, and reviewed:

1. **Stage the work.** `git add` the change — the `commit` skill commits only what
   is **already staged** and never stages for you. Split genuinely distinct
   concerns into separate atomic commits (stage one concern, commit, repeat).
2. **Commit.** Load the `commit` skill and commit each staged group with a
   conventional message (it includes the Jira key when the branch name has one).
   The tree must be clean — `git status` shows nothing to commit — before
   continuing.
3. **Stop at the commit.** Do **not** push and do **not** open a PR. To push the
   branch, use `/implement-worktree`; to open a PR, use `/implement-pr`. Report the
   commit hash(es), the branch, and the files committed.

If a Jira key was passed, run **`/implement`'s Phase 6 — report back to Jira**
(comment the summary + commit hash(es); propose the next transition). Because
nothing is pushed, prefer keeping it *In Progress* rather than *In Review*.

## Done

Report: the branch the commit landed on, the spec summary, any
clarifications/confirms and how they were resolved, the task list with each task's
status, the verify results (tests / build / lint / coverage), the review findings
and how they were resolved, anything noted-but-not-touched, the commit hash(es)
and message(s), and — for a Jira ticket — the comment posted and the ticket's
resulting status. To push the branch or open a PR from here, use
`/implement-worktree` or `/implement-pr`.

## Auto-close this pane (final step)

As the **very last action of this command** — after the Done report above and any
Jira report-back — arm pane auto-close so this opencode pane closes itself the
moment it next goes idle:

!`cat "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/_partials/auto-close-arm.md"`

**Never run it earlier** — the mid-run spec/plan confirm gates also go idle, so
arming before the run is truly finished would close the pane during a gate.
