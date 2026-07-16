---
description: Resolve the merge conflicts on a GitHub PR that's out of date with its base by working inside the existing local git worktree for its head branch (under ~/Programming/wcreated or wcheckout) — locate that worktree (abort if it doesn't exist), merge the freshly-fetched base branch in to surface the conflicts, resolve them preserving both sides, verify build/tests, then finish with a plain non-force git push (never rebase, never force-push)
---

Resolve the merge conflicts on the pull request **$ARGUMENTS** by working inside
the **existing local git worktree** for that PR's head branch — merge the
freshly-fetched base branch **into** the head branch to surface the conflicts,
resolve them so **both** sides' intent survives, verify the tree builds and tests
pass, then finish with a **plain, non-force `git push`**. This **requires** the
worktree to already exist; if it's missing, stop and create it first. It never
rebases and never force-pushes, so it's safe whether the worktree is under
`wcreated` (a branch you own) or `wcheckout` (owned elsewhere).

`$ARGUMENTS` identifies the PR — a number (`123`), a URL
(`github.com/<org>/<repo>/pull/123`), or its head branch name. If no PR is
identified, target the PR for the branch you're on, or ask which PR (offer
`gh pr status` / `gh pr list`).

## Phases — Resolve, locate worktree, merge base in, resolve, verify, push

Load the `resolve-pr-conflicts-worktree` skill with the skill tool and follow it.
It composes `worktree-management` (locate the existing worktree for the PR head
branch), `merge-conflict-resolution` (resolve the conflicts), and a plain
`git push`. Run it as:

1. **Resolve the PR** — capture `owner`/`repo`, `number`, `headRefName`,
   `baseRefName`, and `isCrossRepository`/`mergeable`/`mergeStateStatus`:
   ```bash
   gh pr view <PR> --repo <org>/<repo> --json number,title,url,state,headRefName,baseRefName,author,isCrossRepository,mergeable,mergeStateStatus
   ```
   A fork PR (`isCrossRepository == true`) isn't a branch you can push to — stop.
   If GitHub already reports the PR `MERGEABLE`, there's nothing to resolve — say
   so instead of manufacturing a needless merge commit.
2. **Locate the existing worktree** — from the source clone
   (`~/Programming/<org>/<repo>`), find the worktree whose branch is the head
   branch and whose path is under `~/Programming/wcreated` or
   `~/Programming/wcheckout` (`git -C <repo> worktree list`); confirm it's a
   worktree on the head branch and that its tree is clean. **If it doesn't exist,
   abort** — don't create a worktree and don't edit the main clone; create it
   first via `worktree-management`. Every later phase targets this worktree with
   `git -C <worktree> …`.
3. **Merge the freshly-fetched base into the head branch** — no rebase, no force:
   ```bash
   git -C <worktree> fetch origin <baseRefName>
   git -C <worktree> merge origin/<baseRefName>
   ```
   A clean merge means nothing to resolve → skip to verify + push. A `CONFLICT`
   leaves the merge in progress → Phase 4.
4. **Resolve the conflicts** — load `merge-conflict-resolution` and follow it in
   the worktree. This is a `git merge`, so `--ours`/`HEAD` is the head (feature)
   branch and `--theirs` is the incoming base — the normal mapping. Preserve both
   sides' intent; regenerate lockfiles rather than hand-merging; `git -C
   <worktree> add` each resolved file and never stage one that still has
   `<<<<<<<` / `=======` / `>>>>>>>`.
5. **Verify, then finalize** — `git -C <worktree> diff --check` (no markers), then
   run the project's real checks (install if a lockfile changed, build,
   type-check, lint, tests). Only once green: `git -C <worktree> commit --no-edit`
   to complete the merge.
6. **Push (plain, never force)** — `git -C <worktree> push`; a plain push suffices
   because merging only adds a commit. Then re-check
   `gh pr view <number> --json mergeable,mergeStateStatus` to confirm GitHub now
   sees the PR as mergeable; if the base moved again, re-run from Phase 3.

## Done

Report: the PR number / title / URL, the worktree path + branch + base branch
(and whether it's under `wcreated` or `wcheckout`), whether GitHub reported a real
conflict, the files that had conflicts and how each was resolved (both sides kept
/ one side superseded, with a one-line rationale), the verify results (tests /
build / type-check / lint), the merge commit created, the plain push result, and
the PR's post-push mergeable state. If no worktree existed, report the abort and
the `worktree-management` next step. If the PR was already mergeable, report that
no merge was needed.

## Auto-close this pane (final step)

As the **very last action of this command** — after the Done report — arm pane
auto-close so this opencode pane closes itself the moment it next goes idle:

!`cat "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/_partials/auto-close-arm.md"`

**Never run it earlier** — any mid-run confirm gates also go idle, so arming
before the work is truly finished would close the pane during a gate.
