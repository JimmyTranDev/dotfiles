---
description: Prune every managed git worktree whose branch is ALREADY MERGED into its local base (main/master) or develop via the `worktree clean` operation, deleting the worktree and its local branch (and, for wcreated worktrees, its remote branch); never touches unmerged work
---

Run the dotfiles `worktree clean` workflow to prune every managed worktree
(`~/Programming/wcreated` + `~/Programming/wcheckout`) whose branch is **already
merged** into its local base branch (`main`/`master`) or `develop`, deleting the
worktree and its local branch. Deletion is ownership-aware: a `wcreated` worktree
also deletes its **remote** branch; a `wcheckout` worktree **preserves** the
remote. Worktrees with unmerged commits are left untouched.

Load the `cleanup-worktrees` skill with the skill tool and follow it exactly.

## Invocation

The subcommand lives at `$DOTFILES_DIR/etc/scripts/src/worktrees/worktree`, where
`DOTFILES_DIR="$HOME/Programming/JimmyTranDev/dotfiles"` (see `.zshrc:18`; it is
not exported, so use the explicit path). Invoke it as:

```bash
zsh "$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/worktrees/worktree" clean <flags>
```

## Phase 1 — Preview

1. Run `worktree clean --dry-run` and show me the printed plan: which worktrees
   are merged (into base or `develop`) and will be deleted, and which are skipped
   as not-merged.
2. If nothing is deletable ("No merged worktrees found to clean up." or "No
   worktrees found"), report that and stop.
3. **Confirm gate:** this deletes worktrees, local branches, and — for
   `wcreated` worktrees — remote branches. Ask me to proceed with the question
   tool before making any change.

## Phase 2 — Execute

1. Run `worktree clean -y`. The `-y` skips the interactive `y/N` prompt, which
   reads EOF (-> cancel) when driven non-interactively. Capture its exit code and
   stdout.
2. **Exit 0** -> the merged worktrees were pruned (or nothing was deletable). Go
   to Done.
3. **Any nonzero exit** -> stop and report the error; do not retry blindly.

## Constraints

- **Only prune already-merged branches** (ancestors of base `main`/`master` or
  `develop`). Never delete a worktree with unmerged commits; to integrate one,
  use the `/merge-worktrees` command instead.
- Respect ownership: delete the **remote** branch only for `wcreated` worktrees;
  **preserve** the remote for `wcheckout`. The script already enforces this — do
  not re-derive it.
- Never force-delete a worktree with uncommitted changes; leave it and report it
  as skipped.

## Done

Report: each pruned worktree and the base/`develop` branch it was merged into,
every worktree skipped as not-merged (or skipped for uncommitted changes), and an
explicit note of which deletions removed a **remote** branch (`wcreated`) vs
preserved it (`wcheckout`).
