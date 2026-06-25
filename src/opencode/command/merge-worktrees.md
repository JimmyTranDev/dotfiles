---
description: Merge every managed git worktree's branch into its local base branch (no push), deleting merged and already-merged worktrees; on conflict, resolve via the merge-conflict-resolution skill and continue until clean
---

Run the dotfiles `worktree merge` workflow to integrate every managed worktree
(`~/Programming/wcreated` + `~/Programming/wcheckout`) into its **local** base
branch (`develop` -> `main` -> `master`) with **no push**, deleting each worktree
and its local branch once merged. Already-merged worktrees are just deleted. On a
merge conflict the run stops with the merge left in progress so you resolve it and
continue.

## Invocation

The subcommand lives at `$DOTFILES_DIR/etc/scripts/src/worktrees/worktree`, where
`DOTFILES_DIR="$HOME/Programming/JimmyTranDev/dotfiles"` (see `.zshrc:18`; it is
not exported, so use the explicit path). Invoke it as:

```bash
zsh "$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/worktrees/worktree" merge <flags>
```

`$ARGUMENTS` may contain a standalone, case-insensitive `yolo` token — if present,
skip the confirm gate in Phase 1.

## Phase 1 — Preview

1. Run `worktree merge --dry-run` and show me the printed plan: which worktrees
   will be merged-then-deleted, and which are already-merged (delete-only).
2. If the plan is empty ("Nothing to do — no mergeable or already-merged
   worktrees."), report that and stop.
3. **Confirm gate** (skip if `yolo`): this deletes worktrees and local branches.
   Ask me to proceed with the question tool before making any change.

## Phase 2 — Merge loop

Repeat until `worktree merge` exits `0`:

1. Run `worktree merge -y`. Capture its exit code and stdout.
2. **Exit 0** -> everything merged/deleted (or nothing left). Go to Done.
3. **Exit 2 (conflict)** -> a merge was left in progress in the repo printed as
   `Merge left in progress in: <repo>`:
   a. Load the `merge-conflict-resolution` skill with the skill tool and follow
      it exactly to resolve the conflict in `<repo>`, integrating **both** sides.
   b. Stage the resolved files and finish the merge:
      `git -C <repo> commit --no-edit`. Do **not** push.
   c. Re-run the loop. The next `worktree merge -y` detects the now-merged branch
      as already-merged and deletes its worktree, then proceeds to the next one.
4. **Any other nonzero exit** -> stop and report the error; do not loop.
5. **Loop guard**: if the same `<repo>` conflicts on two consecutive iterations
   with no progress (its worktree was not deleted between runs), stop and report
   — never loop forever.

## Constraints

- **Never push**, and never delete a remote branch — these are local merges only.
- Never force a merge on a worktree with uncommitted changes (the script already
  skips those; leave them alone and report them as skipped).
- Resolve every conflict by integrating both sides; never blindly take one side.

## Done

Report: each worktree's outcome (merged & deleted / already-merged deleted /
skipped-with-reason), every conflict and exactly how it was resolved, the base
branch each was merged into, and an explicit confirmation that **nothing was
pushed**.
