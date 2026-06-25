---
name: merge-conflict-resolution
description: Resolves in-progress git merge/rebase/cherry-pick conflicts safely and verifiably, preserving the intent of BOTH sides instead of blindly picking one. Use when a merge leaves unmerged paths or conflict markers (after `worktree merge`, `git merge`, `git pull`, `git rebase`, or `git cherry-pick`), when `git status` shows "Unmerged paths" / "both modified", or when reconciling two divergent branches. Triggers on "fix the conflicts", "resolve merge conflict", "merge conflict", "unmerged paths", "CONFLICT (content)", "<<<<<<< HEAD". Pairs with the `worktree merge` command, which leaves a conflict in place for this skill to finish; afterward you re-run `worktree merge` to continue. Do NOT use to avoid conflicts via branch strategy — that is git-workflow-and-versioning.
---

# Merge Conflict Resolution

## Overview

A conflicted merge/rebase/cherry-pick is a paused operation: git could not auto-combine two changes and is waiting for a human decision. Resolving it means understanding **why each side changed the code** and producing a result that honors **both** intents — then proving it still builds and passes tests before finalizing. The danger is not the markers; it is silently discarding one side's work by reflexively keeping "ours" or "theirs".

## When to Use

- `git status` reports `Unmerged paths`, `both modified`, `both added`, `deleted by us/them`.
- Files contain `<<<<<<<`, `=======`, `>>>>>>>` markers.
- A `git merge` / `git pull` / `git rebase` / `git cherry-pick` stopped with `CONFLICT`.
- The `worktree merge` command stopped and left a merge in progress for you to finish.

**Do NOT use when:**

- You are choosing a branching/rebase strategy to *avoid* conflicts — use `git-workflow-and-versioning`.
- The working tree is clean and nothing is mid-operation (`git status` shows no unmerged paths) — there is nothing to resolve.

## The Workflow

### 1. Stop and assess — never guess

```
git status                 # which operation is in progress + unmerged paths
git diff --name-only --diff-filter=U   # exact conflicted files
```

Do not edit anything until you know the operation type, because it flips what `ours`/`theirs` mean (Step 2).

### 2. Pin down ours vs theirs (it inverts per operation)

| Operation in progress | `--ours` / `HEAD` side | `--theirs` side |
|---|---|---|
| `git merge` (and `worktree merge`) | the branch you are merging **into** (the base, e.g. `main`) | the branch being merged **in** (the feature) |
| `git rebase` | the branch you are replaying **onto** (upstream/base) | **your** commits being replayed |
| `git cherry-pick` | current branch (`HEAD`) | the commit being picked |

Rebase inverts intuition: "theirs" is *your own* work. Confirm before using `checkout --ours/--theirs`.

### 3. Understand both sides of each conflict

For every conflicted file:

```
git log --merge -p -- <file>   # the commits from each side touching this file
git diff -- <file>             # the conflict hunks in context
```

Read the surrounding code and the commit messages. Decide the *combined* correct behavior — usually you keep logic from both sides, not one. Resolve by editing the file and deleting all three marker lines (`<<<<<<<`, `=======`, `>>>>>>>`).

### 4. Handle generated / lock files by regenerating, not hand-merging

Never hand-merge machine-generated files — pick a base, then regenerate:

- `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` / `bun.lock`: `git checkout --theirs <lock>` (or `--ours`), then re-run the install (`npm install` / `pnpm install` / `yarn` / `bun install`) so the lockfile is regenerated against the merged `package.json`, then stage it.
- Snapshots, compiled assets, `dist/`, schema dumps: regenerate from source rather than reconciling markers.
- A pure rename/move vs edit: prefer `git checkout --ours`/`--theirs` for the whole file when one side only moved it.

### 5. Stage each resolved file

```
git add <file>          # marks it resolved
# deletion conflicts: `git rm <file>` (accept delete) or `git add <file>` (keep it)
```

### 6. Verify the resolution before committing

```
git diff --check                       # fails if any conflict marker remains
git grep -nE '^(<<<<<<<|=======|>>>>>>>)' || true   # belt-and-suspenders
```

Then run the project's real checks (detect from the repo): build, type-check, lint, and the test suite. A resolution that drops a side often compiles but breaks tests — tests are the proof. Do not finalize on a clean `git diff --check` alone.

### 7. Finalize the paused operation

```
git merge --continue        # or: git commit --no-edit   (merge)
git rebase --continue       # (rebase — repeat steps 3-6 per stopped commit)
git cherry-pick --continue  # (cherry-pick)
```

### 8. If it is unsalvageable, abort cleanly

```
git merge --abort | git rebase --abort | git cherry-pick --abort
```

Aborting restores the pre-operation state — a legitimate outcome when the merge is wrong or out of scope. Report why instead of forcing a bad resolution.

### 9. `worktree merge` follow-through

When this conflict came from `worktree merge`: after Step 7 commits the merge into the base branch, **re-run `worktree merge`**. The now-merged branch is detected as already-merged, its worktree is deleted, and the remaining worktrees continue.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Just take theirs/ours to clear it fast." | That silently deletes the other side's work. Combine intents; only take a whole side when one side genuinely supersedes the other. |
| "In a rebase, theirs is the upstream." | Inverted: in a rebase `--theirs` is *your* replayed commits. Re-check Step 2 before any `checkout --ours/--theirs`. |
| "Markers are gone, so it's resolved." | Removing markers only ends the syntax conflict. Run the build and tests — semantic conflicts compile and still break. |
| "I'll hand-edit the lockfile diff." | Lockfiles must be regenerated by the package manager, not merged by hand, or you corrupt the dependency tree. |
| "Commit now, fix tests later." | A green test run is the resolution's proof. Finalize only after verification passes. |
| "Force-push to make the conflict go away." | That destroys history and hides the problem. Resolve the conflict; never paper over it. |

## Red Flags

- Running `git checkout --ours`/`--theirs` without first confirming the operation type.
- Deleting one side's hunk without reading why it changed.
- `git add`-ing a file that still contains `<<<<<<<` / `=======` / `>>>>>>>`.
- Committing the merge before the build/test suite passes.
- Hand-editing `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` conflict hunks.
- Leaving the repo mid-merge and walking away (re-run `worktree merge` or abort).

## Verification

- [ ] `git diff --check` reports no conflict markers and `git grep` finds none.
- [ ] `git status` shows no remaining `Unmerged paths`.
- [ ] Build, type-check, lint, and tests all pass on the resolved tree (evidence, not assumption).
- [ ] The final commit preserves the intended behavior of **both** sides (or a deliberate, stated decision to supersede one).
- [ ] The paused operation was finalized (`--continue`/commit) or cleanly aborted (`--abort`) — the repo is never left mid-operation.
- [ ] If from `worktree merge`: the merge was committed and `worktree merge` was re-run to continue.
