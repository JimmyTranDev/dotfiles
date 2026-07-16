---
name: resolve-pr-conflicts-worktree
description: Resolves the merge conflicts on a GitHub PR that is out of date with its base branch, working INSIDE the existing local git worktree for that PR's head branch (under ~/Programming/wcreated or ~/Programming/wcheckout) and finishing with a plain, non-force push. Locates the worktree for the head branch (ABORTS if missing — never creates one), merges the freshly-fetched base branch into the head branch to surface the conflicts, resolves them preserving BOTH sides, verifies build/tests, then `git push` (never force). Composes worktree-management (locate worktree), merge-conflict-resolution (resolve), and git push. Use for "fix the PR conflicts in my worktree", "the PR has merge conflicts, resolve them and push", "resolve conflicts on PR #123 in its worktree". Do NOT use to resolve an already-in-progress conflict in a plain clone (that is merge-conflict-resolution), to rebase/force-push a branch, or to handle review comments (that is fix-worktree / handle-pr-comments-worktree).
---

# Resolve PR Conflicts in Its Local Worktree

## Overview

A pull request has drifted behind its base branch and GitHub reports **merge
conflicts** ("This branch has conflicts that must be resolved"). This skill fixes
that from the **existing local git worktree** for the PR's head branch: it merges
the freshly-fetched base branch **into** the head branch to surface the conflicts,
resolves them so **both** sides' intent survives, verifies the tree builds and
tests pass, and finishes with a **plain, non-force `git push`** so the PR updates
without rewriting history.

It **composes** three existing skills and duplicates none:
`worktree-management` locates the worktree, `merge-conflict-resolution` does the
actual conflict resolution, and the final step is a normal `git push`.

**Strategy is fixed: merge the base in, then plain-push.** This skill never
rebases and never force-pushes — that keeps it safe on a branch under review and
works identically whether the worktree is under `wcreated` (a branch you own) or
`wcheckout` (a branch owned elsewhere). If you specifically want a rebased,
force-pushed history, that is out of scope here.

## When to Use

- A PR is marked "conflicting" / out of date with its base, and its head branch
  already has a local worktree under `~/Programming/wcreated` or
  `~/Programming/wcheckout`.
- "Fix the PR conflicts in my worktree", "resolve conflicts on PR #123 and push",
  "the PR can't merge — reconcile it with `main` in its worktree".

**Do NOT use when:**

- No worktree exists for the head branch — this skill **aborts**; create one via
  `worktree-management` (Workflow A for a branch you own, Workflow B to check out
  an existing remote branch), or resolve in a plain clone with
  `merge-conflict-resolution`.
- A conflict is **already in progress** in a plain clone (unmerged paths right
  now) — go straight to `merge-conflict-resolution`.
- You want a **rebased / force-pushed** branch — out of scope (this skill only
  merges + plain-pushes).
- You are handling **review comments**, not conflicts — that is `fix-worktree` or
  `handle-pr-comments-worktree`.
- It is a **fork PR** you cannot push to (`isCrossRepository == true`) — you can't
  update its branch; coordinate with the author instead.

## Prerequisites

- `gh` authenticated (`gh auth status`) to resolve the PR.
- The head branch's worktree **already exists** under `wcreated` or `wcheckout`.
- A clean working tree in that worktree before starting (commit or stash first).

## The Workflow

```
Resolve PR ─→ locate EXISTING worktree ─→ merge base in ─→ resolve conflicts ─→ verify ─→ plain push
 (Phase 1)     (Phase 2 — abort if none)   (Phase 3)        (Phase 4)            (Phase 5)  (Phase 6)
```

### 1. Resolve the PR

Identify the PR and capture the fields that drive everything else:

```bash
gh pr view <PR> --repo <org>/<repo> --json number,title,url,state,headRefName,baseRefName,author,isCrossRepository,mergeable,mergeStateStatus
```

- `isCrossRepository == true` → a fork PR you can't push to. **Stop.**
- `mergeable`/`mergeStateStatus` tell you whether GitHub even sees a conflict; a
  `CONFLICTING` state confirms the job. (A `MERGEABLE` PR may have nothing to do —
  say so rather than forcing a needless merge commit.)

Record `owner`, `repo`, `number`, `headRefName`, `baseRefName`.

### 2. Locate the existing worktree (required — never create one)

Load `worktree-management` for its environment model (`WCREATED_DIR =
~/Programming/wcreated`, `WCHECKOUT_DIR = ~/Programming/wcheckout`). From the
source clone (`~/Programming/<org>/<repo>`), find the worktree whose branch is the
head branch:

```bash
git -C <repo> worktree list
```

Select the worktree whose branch is `<headRefName>` and whose path is under
`WCREATED_DIR` or `WCHECKOUT_DIR`. Confirm and note ownership (it does **not**
change the strategy here, only the reporting):

```bash
git -C <worktree> rev-parse --is-inside-work-tree
git -C <worktree> branch --show-current      # must equal <headRefName>
```

**If no such worktree exists, ABORT.** Do not create one and do not edit the main
clone — point the user at `worktree-management` (Workflow A/B) first. Every later
phase runs in this worktree via `git -C <worktree> …`.

Confirm the tree is clean before touching it:

```bash
git -C <worktree> status --short          # must be empty; commit or stash otherwise
```

### 3. Merge the freshly-fetched base into the head branch

Fetch the base and merge it in (no force, no rebase):

```bash
git -C <worktree> fetch origin <baseRefName>
git -C <worktree> merge origin/<baseRefName>
```

- If the merge completes cleanly, there was nothing to resolve — skip to Phase 5
  (verify) and Phase 6 (push the merge commit that catches the branch up).
- If it stops with `CONFLICT`, the merge is now in progress and the working tree
  has unmerged paths — proceed to Phase 4.

### 4. Resolve the conflicts (delegate to merge-conflict-resolution)

Load and follow the `merge-conflict-resolution` skill inside this worktree. Key
points it enforces, restated because they matter here:

- This is a **`git merge`**, so `--ours`/`HEAD` is the **head (feature) branch**
  and `--theirs` is the incoming **base branch** — the normal, non-inverted
  mapping.
- Resolve each conflict preserving **both** sides' intent; don't blindly take one
  side. Regenerate lockfiles/generated files rather than hand-merging.
- `git -C <worktree> add <file>` each resolved file; never stage a file that still
  contains `<<<<<<<` / `=======` / `>>>>>>>`.

### 5. Verify before finalizing

Prove the resolution is sound — a dropped side often still compiles:

```bash
git -C <worktree> diff --check                              # no leftover markers
git -C <worktree> grep -nE '^(<<<<<<<|=======|>>>>>>>)' || true
```

Then run the project's real checks (detect from the repo): install (if a lockfile
changed), build, type-check, lint, and the test suite. Only continue once they
pass.

Finalize the merge commit:

```bash
git -C <worktree> commit --no-edit        # completes the in-progress merge
```

(If Phase 3 merged cleanly, this commit already exists — nothing to do here.)

### 6. Push (plain, never force)

```bash
git -C <worktree> push
```

A plain push suffices because merging only **adds** a commit — history isn't
rewritten. **Never** `--force` / `--force-with-lease` here. Then confirm GitHub
now sees the PR as mergeable:

```bash
gh pr view <number> --repo <owner>/<repo> --json mergeable,mergeStateStatus
```

If it still reports conflicting, the base moved again mid-flow — re-run from
Phase 3.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "No worktree exists, I'll just make one / edit the main clone." | This skill **requires** an existing worktree and aborts without one. Create it via `worktree-management` first. |
| "Rebase onto base for a clean history." | Out of scope — this skill only merges + plain-pushes. Rebasing forces a force-push, which is unsafe on a branch under review. |
| "Force-push to make the conflict go away." | Never. Merging adds a commit; a plain `git push` is all that's needed. Force-push destroys history. |
| "Take theirs/ours to clear it fast." | That silently drops one side's work. Combine both intents (see merge-conflict-resolution). |
| "Markers are gone, so it's resolved — push it." | Removing markers ends only the syntax conflict. Build + tests are the proof; run them before committing. |
| "GitHub says mergeable but I'll merge anyway." | Nothing to resolve — don't manufacture a needless merge commit. Report it's already mergeable. |
| "Hand-merge the lockfile diff." | Regenerate lockfiles with the package manager; never hand-edit their conflict hunks. |

## Red Flags

- Creating a worktree instead of aborting when none exists.
- Rebasing, or pushing with `--force` / `--force-with-lease`.
- Starting the merge on a dirty worktree (uncommitted changes get entangled).
- `git add`-ing a file that still contains conflict markers.
- Committing/pushing before the build and test suite pass.
- Merging a PR that GitHub already reports as mergeable.
- Trying to push a fork PR's branch you don't own.

## Verification

- [ ] PR resolved; `owner`/`repo`/`number`/`headRefName`/`baseRefName` captured; fork PRs routed away.
- [ ] An **existing** worktree on the head branch was **located, not created** (aborted if missing); tree was clean before starting.
- [ ] Base branch was fetched and **merged** into the head branch (no rebase).
- [ ] All conflicts resolved via `merge-conflict-resolution`, preserving both sides; no markers remain (`git diff --check` clean).
- [ ] Build, type-check, lint, and tests pass on the resolved tree.
- [ ] Merge commit finalized and pushed with a **plain** `git push` (no force); GitHub now reports the PR mergeable.
