---
name: worktree-clean
description: Delete all worktrees that don't have open PRs and remove their branches
---

Usage: /worktree-clean

Delete worktrees that are no longer associated with an open PR. Always removes the branch too.

## Workflow

1. Load the **git-worktree-workflow** skill

2. Gather state in parallel:
   - `git worktree list --porcelain` to get all worktrees and their branches
   - `pr-status.sh` to get branches with open PRs (parse `PR_BRANCH` values from output)

3. Filter worktrees:
   - Exclude the main working tree (bare repo or primary clone)
   - Exclude the current working directory
   - For each remaining worktree, check if its branch matches any open PR branch name

4. For worktrees without open PRs:
   - Check for uncommitted changes via `git -C <path> status --porcelain`
   - If uncommitted changes exist, warn and skip that worktree
   - Otherwise, add to the removal list

5. Present the removal list to the user and ask for confirmation:
   - Show each worktree path and branch name
   - If the list is empty, report "All worktrees have open PRs" and stop

6. After confirmation, for each worktree:
   - `git worktree remove <path>`
   - `git branch -D <branch-name>`

7. Run `git worktree prune` to clean stale references

8. Report summary: "Removed N worktrees: [branch-list]"

## Rules

- Never remove the main working tree
- Never remove the current working directory
- Always skip worktrees with uncommitted changes (warn the user)
- Always delete the branch after removing the worktree
