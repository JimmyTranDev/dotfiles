---
description: Merge every managed git worktree's branch into its local base branch (no push), deleting merged and already-merged worktrees; on conflict, resolve via the merge-conflict-resolution skill and continue until clean
---

Run the dotfiles `worktree merge` workflow to integrate every managed worktree
(`~/Programming/wcreated` + `~/Programming/wcheckout`) into its **local** base
branch (`develop` -> `main` -> `master`) **checkout-free**: **rebase** each branch
onto its base in the worktree, then **advance the base ref** onto it with a
checkout-free `update-ref` (linear history, no merge commit, **no push**, and the
base is **never checked out or mutated** in the main repo — its HEAD is detached
at the old base commit when it had the base checked out). Each worktree and its
local branch are deleted once integrated. Already-merged worktrees are just
deleted. On a rebase conflict the run stops with the rebase left in progress in
the worktree so you resolve it and continue.

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
2. **Exit 0** -> everything integrated/deleted (or nothing left). Go to Done.
3. **Exit 2 (conflict)** -> a rebase was left in progress in the worktree printed
   as `Rebase left in progress in the worktree: <wt_path>`:
   a. Load the `merge-conflict-resolution` skill with the skill tool and follow
      it exactly to resolve the conflict in `<wt_path>`, integrating **both** sides.
   b. Stage the resolved files and continue the rebase:
      `git -C <wt_path> add -A && git -C <wt_path> rebase --continue` (repeat for
      each stopped commit). Do **not** push.
   c. Re-run the loop. The next `worktree merge -y` detects the now-rebased branch
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
