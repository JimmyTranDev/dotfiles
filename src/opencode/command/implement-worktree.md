---
description: Implement a feature or Jira ticket end-to-end inside a dedicated wcreated git worktree — spec, plan, build, verify, review — then stop at a committed, pushed branch (no PR); pass a `yolo` keyword to run autonomously with no gates
---

Implement **$ARGUMENTS** inside a dedicated `wcreated` git worktree, then stop at
a committed, pushed branch — **no pull request** (use `/implement-pr` to open
one). This is the `/implement` flow run inside a fresh worktree.

## Modifiers — parse `$ARGUMENTS` first

Read the same two optional modifiers as `/implement`, then treat the remainder
as the task:

- **`yolo` keyword** — a standalone, case-insensitive `yolo` token switches this
  run to the **autonomous** flow (no go/no-go gates; pause only for a genuinely
  blocking ambiguity). Strip it before reading the description. Absent →
  **gated** (confirm gate after the spec and after the plan).
- **Jira key / URL** — `^[A-Z]+-[0-9]+$` or `*.atlassian.net/browse/<KEY>` turns
  on Jira intake + report-back and seeds the spec's success criteria from the
  ticket's acceptance criteria.

If nothing remains and no Jira key was given, ask what to implement first.

## Phase 0 — Worktree setup

1. Load the `worktree-management` skill with the skill tool and follow its
   **wcreated** workflow (Workflow A) exactly — raw `git`, never the worktree
   shell script.
2. Create a **new branch worktree** under `~/Programming/wcreated`, branched off
   the freshly-updated base branch (`develop` → `main` → `master`):
   - **Jira key**: name the branch `<KEY>-<slug(summary)>`, pulling the summary
     via `acli` when available (fall back to `<KEY>`).
   - **Otherwise**: derive the branch/slug from the description.
3. Let the skill choose the commit type, seed the empty commit (so the branch is
   pushable immediately), install deps if a lockfile exists, and `cd` into the
   new worktree.
4. Confirm you are inside the worktree (`git rev-parse --is-inside-work-tree`)
   and on the new branch (`git branch --show-current`) before writing any code.
   **Every** subsequent phase runs inside this worktree.

If a Jira key was passed, now run **`/implement`'s Phase 0 — Jira intake** (read
the ticket + self-assign + move to *In Progress* + pull any linked Figma) inside
the worktree.

Carry the branch name and the base branch it was cut from into the later phases.

## Phases 1–5 — Spec · Plan · Build · Verify · Review

Run the **identical** core flow from `/implement` (Phases 1–5), honoring the
`yolo` modifier (gated confirm gates vs. autonomous clarify-only) and any Jira
acceptance criteria, all inside the worktree.

## Phase 6 — Stop at a pushed branch (no PR)

Once the change is built, verified, and reviewed:

1. **Commit everything.** Load the `commit` skill and commit all work with
   conventional messages (include the Jira key when present). The tree must be
   clean — `git status` shows nothing to commit — before continuing.
2. **Push the branch:** `git push -u origin <branch>`.
3. **Report, don't publish.** Print the worktree path, branch, base branch, and
   the exact command to open a PR later:
   ```bash
   gh pr create --base <base> --title "<title>" --body "<body>"
   ```
   To open the PR as part of the run instead, use `/implement-pr`.

If a Jira key was passed, run **`/implement`'s Phase 6 — report back to Jira**
(comment the summary + pushed branch; propose the next transition).

## Done

Report: the worktree path + branch + base branch, the spec summary, any
clarifications/confirms and how they were resolved, the task list with each
task's status, the verify results (tests / build / lint / coverage), the review
findings and how they were resolved, anything noted-but-not-touched, the
`gh pr create` command to open a PR later, and — for a Jira ticket — the comment
posted and the ticket's resulting status.
