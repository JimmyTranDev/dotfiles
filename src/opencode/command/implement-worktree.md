---
description: Implement a feature or Jira ticket end-to-end inside a dedicated wcreated git worktree — spec, plan, build, verify, review — then commit and push the branch (no PR) and optionally rebase it onto its base branch, merge, and clean up the worktree; pass a `yolo` keyword to run autonomously with no gates
---

Implement **$ARGUMENTS** inside a dedicated `wcreated` git worktree, commit and
push the branch — **no pull request** (use `/implement-pr` to open one) — then
**optionally rebase it onto the base branch, merge, and clean up the worktree**. This is
the `/implement` flow run inside a fresh worktree.

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

**First, clear the spec/plan artifacts.** Remove the repo-root `spec/` folder
(`rm -rf spec/`) so the spec (`spec/spec.md`) and plan (`spec/plan.md`) working
files never reach the pushed branch or the base branch — do it before the commit
below so the removal lands in the finalize commit.

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

## Phase 7 — Rebase, merge & clean up (optional)

With the branch committed and pushed, offer to **rebase it onto its base** (the
`develop`/`main`/`master` it was cut from), **merge** it, and **clean up the
worktree** — no PR needed.

- **Gated (default)** — use the `question` tool with exactly these three
  options:
  - **Rebase onto `<base>`, resolve conflicts, merge & clean up (Recommended)** —
    the change is already verified and reviewed, so replay it onto the base for
    linear history, merge it in, and tidy up.
  - **Keep the pushed branch (no merge)** — leave the branch and worktree as-is
    and decide later; the `gh pr create` command from Phase 6 is already printed.
  - **Open a PR now instead** — go through review rather than a direct merge by
    running the `gh pr create` command from Phase 6 (the branch is already
    pushed).
- **`yolo`** — **never auto-merge.** Pushing a shared base branch and deleting
  branches are external side effects, so skip the question, leave the pushed
  branch, and report that rebase + merge + cleanup is available.

When **rebase, merge & clean up** is chosen, do it in this order — rebase, then
merge, because cleanup deletes the branch.

1. **Rebase onto, then merge into, the base — serialized & concurrency-safe.** Several
   `/implement-worktree` runs can finish at once and all target the **same base
   branch in the same main repo**, which a repo cannot do concurrently (one
   checked-out base, one in-progress merge) and which races on push. Do **not**
   merge by hand — delegate to the helper, which takes a per-repo lock, **waits**
   when another merge is already running (reclaiming a stale one), brings the
   base up to date, **rebases the branch onto it** for linear history, merges
   `--no-ff`, and retries the push on a non-fast-forward race. It resolves the
   main repo, base, and feature branch from the worktree:
   ```bash
   zsh "$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/worktrees/merge-into-base.sh" \
     merge --worktree "<worktree>"
   ```
   Act on its **exit code** — only proceed to cleanup once the merge reaches `0`:
   - **`0`** — merged and pushed; continue to cleanup.
   - **`2`** — a conflict handed back for you to resolve, of one of two kinds.
     For either, load the `merge-conflict-resolution` skill, resolve every
     conflict preserving both sides, and for lockfiles / generated files
     **regenerate** them (re-run the package manager / generator) rather than
     hand-merging:
     - **Rebase conflict — in the worktree, lock RELEASED.** Replaying the
       branch onto the base hit a conflict, so the rebase is left **in progress
       in the worktree** and the lock is already freed (resolution happens
       off-lock). Resolve in the worktree, then `git -C "<worktree>" add -A &&
       git -C "<worktree>" rebase --continue` (repeat for each stopped commit).
       Once the rebase finishes, **re-run the same `merge` command** — it
       re-acquires the lock and merges the now-linear branch.
     - **Merge conflict — in the main repo, lock RETAINED.** Merging into the
       base (or integrating the remote base during the push) conflicted, so the
       merge is left **in progress in the main repo** with the lock **retained**
       for you (`repo=$(dirname "$(git -C <worktree> rev-parse --path-format=absolute --git-common-dir)")`).
       Resolve it there, `git -C "$repo" commit --no-edit`, then re-run the
       helper with `finalize --worktree "<worktree>"` to push and release the
       lock; if `finalize` itself returns `2`, repeat resolve → commit →
       `finalize`.
     To abandon either case, run the helper's `abort --worktree "<worktree>"`
     (aborts any in-progress rebase/merge and releases the lock).
   - **`3`** — precondition failed: the base repo **or the worktree** has
     uncommitted changes, or the base repo is stuck in a foreign/abandoned
     merge. **Do not clean up.** Report it so the offending repo can be made
     clean, then retry.
   - **`4`** — timed out waiting for another merge still in progress. **Do not
     clean up.** Report it; the branch is pushed and the merge is still available
     to retry later.
2. **Clean up the worktree.** Load the `worktree-management` skill and run its
   **Workflow C (delete a worktree)** — this is a `wcreated` worktree, so it
   removes the worktree and deletes the branch **locally and on the remote**.

If a Jira key was passed and the branch was merged, propose the workflow's
**done/closed** transition (e.g. `"Done"`) instead of `"In Review"`.

## Done

Report: the worktree path + branch + base branch, the spec summary, any
clarifications/confirms and how they were resolved, the task list with each
task's status, the verify results (tests / build / lint / coverage), the review
findings and how they were resolved, anything noted-but-not-touched, the
**rebase/merge & cleanup decision and its outcome** (rebased onto and merged
into `<base>` and the worktree removed, or the branch + worktree kept), the `gh pr create` command to
open a PR later (when the branch was kept), and — for a Jira ticket — the comment
posted and the ticket's resulting status.

## Auto-close this pane (final step)

As the **very last action of this command** — after the Done report above,
including the Phase 7 rebase/merge/cleanup decision and any Jira report-back — arm pane
auto-close so this opencode pane closes itself the moment it next goes idle:

!`cat "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/_partials/auto-close-arm.md"`

**Never run it earlier** — the mid-run spec/plan confirm gates (and the Phase 7
question) also go idle, so arming before the run is truly finished would close
the pane during a gate.
