---
description: Create a dedicated git worktree, implement the work end-to-end (spec → plan → build → verify → review with quick confirms after the spec and plan), then offer to open the result as a draft PR, a ready-for-review PR, or no PR
---

Implement **$ARGUMENTS** inside a dedicated git worktree, then publish it as a
pull request. This is the gated `/implement` flow (**spec → plan → build →
verify → review**, auto-advancing with a quick confirm after the spec and after
the plan) run inside a fresh `wcreated` worktree, finishing by asking how to
open the PR.

`$ARGUMENTS` is either a Jira key (e.g. `ABC-123`) or a short feature
description. If empty, ask what to implement before starting.

## Phase 0 — Worktree setup

1. Load the `worktree-management` skill with the skill tool and follow its
   **wcreated** workflow (Workflow A) exactly — raw `git`, never the worktree
   shell script.
2. Create a **new branch worktree** under `~/Programming/wcreated`, branched off
   the freshly-updated base branch (`develop` → `main` → `master`):
   - **Jira key** (`^[A-Z]+-[0-9]+$`): name the branch `<KEY>-<slug(summary)>`,
     pulling the summary via `acli` when available (fall back to `<KEY>`).
   - **Otherwise**: derive the branch/slug from the description.
3. Let the skill choose the commit type, seed the empty commit (so the branch is
   pushable/PR-able immediately), install deps if a lockfile exists, and `cd`
   into the new worktree.
4. Confirm you are inside the worktree (`git rev-parse --is-inside-work-tree`)
   and on the new branch (`git branch --show-current`) before writing any code.
   **Every** subsequent phase runs inside this worktree.

Carry the branch name and the base branch it was cut from into the later phases —
the PR head is this branch and the PR base is that base branch.

## Phase 1 — Spec · Phase 2 — Plan · Phase 3 — Build · Phase 4 — Verify · Phase 5 — Review

Run the **identical** core flow from the `/implement` command, all inside the
worktree:

1. **Spec** — load `spec-driven-development`; surface assumptions first, then
   write a concise spec (objective, testable success criteria, scope
   always/ask-first/never, open questions) proportional to the task. For a Jira
   key, the **success criteria are the ticket's acceptance criteria**.
   **Confirm gate** via the `question` tool: *Proceed to planning (Recommended)*
   / *Revise the spec first* / *Stop here*. Do not plan until "Proceed".
2. **Plan** — load `planning-and-task-breakdown`; ordered, dependency-aware S–M
   tasks (≤ ~5 files each), every task with acceptance criteria + a verification
   step; prefer vertical slices.
   **Confirm gate** via the `question` tool: *Proceed to build (Recommended)* /
   *Revise the plan first* / *Stop here*. Do not write code until "Proceed".
3. **Build** — load `incremental-implementation` + `test-driven-development`
   (and `source-driven-development` for framework specifics). Implement every
   task to completion: test → smallest slice → run tests/build/lint → keep the
   tree green. Track progress with a todo list; touch only what each task
   requires. Only stop for a genuinely blocking ambiguity or an
   irreversible/destructive action.
4. **Verify** — run the **full** tests/build/lint/type-check and confirm every
   spec success criterion is met. On failure load `debugging-and-error-recovery`
   and fix the **root cause**; ensure new/changed logic is meaningfully covered
   (load `testability-and-coverage` if thin); for high-stakes/irreversible logic
   load `doubt-driven-development`. Don't proceed until the suite is green.
5. **Review** — load `code-review-and-quality` and review the whole change
   across every axis (correctness, design, tests, security, readability) as if
   it were someone else's PR. Fix anything that wouldn't pass, then **re-verify**
   (Phase 4).

## Phase 6 — Pull request

Once the change is built, verified, and reviewed:

1. **Commit everything.** Load the `commit` skill and commit all work with
   conventional messages (include the Jira key when present). The tree must be
   clean — `git status` shows nothing to commit — before continuing.
2. **Push the branch:** `git push -u origin <branch>`.
3. **Ask how to publish.** Use the `question` tool with exactly these three
   options:
   - **Draft PR (Recommended)** — open a draft so CI runs and you can do a final
     pass in the PR UI before pinging reviewers; mark ready in one click later.
     `gh pr create --draft --base <base> --title "<title>" --body "<body>"`
   - **Open PR (ready for review)** — the work is already verified and reviewed,
     so request review immediately.
     `gh pr create --base <base> --title "<title>" --body "<body>"`
   - **No PR** — stop after pushing; report the branch and the exact
     `gh pr create` command to open one later.
4. **Create the PR** for the chosen option (skip for *No PR*). Set:
   - `--base` to the worktree's base branch (the `develop`/`main`/`master` it was
     cut from); head is the current branch.
   - **Title** from the spec objective (or `<KEY> <summary>` for a Jira ticket).
   - **Body** summarizing what changed and how it was verified (tests/build/lint),
     plus the Jira link `https://storebrand.atlassian.net/browse/<KEY>` when a
     ticket exists.

   Report the PR URL.

## Done

Report: the worktree path + branch + base branch, the spec summary, the task
list with each task's status, the verify results (tests / build / lint /
coverage), the review findings and how they were resolved, anything
noted-but-not-touched, and the PR decision (draft / ready / none) with its URL —
or, for *No PR*, the `gh pr create` command to open one later.
