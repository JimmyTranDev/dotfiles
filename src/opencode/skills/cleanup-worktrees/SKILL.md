---
name: cleanup-worktrees
description: Safely prunes managed git worktrees whose branch is ALREADY MERGED into its base — the `worktree clean` operation — across ~/Programming/wcreated and ~/Programming/wcheckout, ownership-aware (wcreated also deletes the remote branch; wcheckout preserves it). Use when you want to clean up, prune, or bulk-remove merged / stale / finished worktrees, or run the `/cleanup-worktrees` command. Triggers on "clean up worktrees", "prune merged worktrees", "delete merged worktrees", "remove stale worktrees", "worktree clean", "cleanup-worktrees". Only deletes branches already merged into base (main/master) or develop — never unmerged work. Use ONLY for pruning already-merged worktrees: to MERGE an unmerged branch then delete it use the merge-worktrees command with merge-conflict-resolution, and for raw-git create/checkout/delete mechanics and the wcreated-vs-wcheckout remote rules use worktree-management.
---

# Cleanup Worktrees

## Overview

Prune every managed worktree whose branch has **already been merged** into its
base branch, then delete the worktree and its branch. This is safe by
construction: a merged branch's commits already live in the base, so removing the
worktree discards nothing. It is the batch "tidy up finished work" pass over
`~/Programming/wcreated` and `~/Programming/wcheckout`, exposed as the
`worktree clean` subcommand and the `/cleanup-worktrees` command.

The rule that keeps it safe: **only delete branches that are ancestors of the
base** (`main`/`master`) **or `develop`**. Anything with unmerged commits is left
untouched.

## When to Use

- "Clean up / prune / remove my merged (or stale, finished) worktrees."
- Reclaiming a pile of worktrees whose PRs already merged.
- Running the `/cleanup-worktrees` command.

**Do NOT use when:**

- The branch is **not yet merged** and you want to integrate it — that is
  merging, not cleanup. Use the `merge-worktrees` command (`worktree merge`),
  resolving conflicts with `merge-conflict-resolution`.
- You are creating, checking out, or deleting a **single** worktree by hand — use
  `worktree-management`.
- You just want to see what exists without deleting — `worktree list`.

## Ownership Semantics (inherited)

Deletion is **location-aware**, exactly as in `worktree-management`:

- Under `~/Programming/wcreated` → you own the branch, so its **remote** branch is
  deleted too.
- Under `~/Programming/wcheckout` → the branch is owned elsewhere, so the **remote
  is preserved**.

The `worktree clean` script already enforces this (via `delete_single_worktree`);
do not re-derive it.

## Workflow

### Preferred: the `worktree clean` subcommand

The script lives at
`$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/worktrees/worktree`
(`DOTFILES_DIR` is not exported, so use the explicit path).

1. **Preview** — never delete blind:
   ```bash
   zsh "$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/worktrees/worktree" clean --dry-run
   ```
   It scans every worktree, marks each branch merged (into base or `develop`) or
   not, and prints the exact set it would delete. `--dry-run` changes nothing.
2. **Confirm** — deleting worktrees, local branches, and (for `wcreated`) remote
   branches is destructive. Get a go-ahead before proceeding.
3. **Execute** without the interactive prompt:
   ```bash
   zsh "$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/worktrees/worktree" clean -y
   ```
   Without `-y` the script blocks on a `y/N` prompt, which reads EOF (→ cancel)
   when driven non-interactively — so pass `-y` from an agent.
4. **Report** which worktrees were deleted and which were skipped as not-merged.

### Manual / raw-git fallback

When the script is unavailable or you want per-worktree control, for each
worktree under `wcreated`/`wcheckout`:

1. `repo=$(dirname "$(git -C <wt> rev-parse --path-format=absolute --git-common-dir)")`
2. `branch=$(git -C <wt> branch --show-current)`; fetch the repo once.
3. **Merged?** `git -C <repo> merge-base --is-ancestor <branch> origin/<base>`
   (also try `origin/develop`). If it is **not** an ancestor, skip it.
4. If merged, delete it via `worktree-management` **Workflow C** so the
   wcreated-deletes-remote / wcheckout-preserves-remote rule still applies.

Never hand-roll the deletion + remote logic — defer to `worktree-management`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This branch is basically done, just delete it." | "Basically" isn't merged. Only delete ancestors of base/develop; unmerged work stays. |
| "Delete the remote for this checkout too." | No. Only `wcreated` deletions touch the remote; `wcheckout` preserves it. Location decides. |
| "Run `worktree clean` without `-y`." | Non-interactive stdin is EOF, so the `y/N` prompt cancels and nothing happens. Preview with `--dry-run`, then execute with `-y`. |
| "It's unmerged but stale — cleanup should force it." | Cleanup never force-deletes unmerged branches. Integrate it with `merge-worktrees`, or drop it explicitly via `worktree-management`. |
| "Skip the `--dry-run` preview." | Deletion is destructive (including remote branches). Always preview the set first. |

## Red Flags

- Deleting a worktree whose branch is **not** an ancestor of base or `develop`.
- Running `git push origin --delete` for a `wcheckout` worktree.
- Force-deleting a worktree with **uncommitted changes** instead of skipping it.
- Re-implementing the deletion/remote logic instead of using `worktree clean` or
  `worktree-management` Workflow C.
- Running `clean -y` without having previewed via `--dry-run` first.

## Verification

- [ ] Previewed with `worktree clean --dry-run` and the delete set is exactly the
      already-merged worktrees.
- [ ] Every deleted branch was an ancestor of base (`main`/`master`) or `develop`;
      no unmerged worktree was removed.
- [ ] Remote branches deleted **only** for `wcreated` worktrees; `wcheckout`
      remotes preserved.
- [ ] Worktrees with uncommitted changes or a corrupted `.git` were skipped, not
      forced.
- [ ] `git -C <repo> worktree list` no longer shows the pruned worktrees.
