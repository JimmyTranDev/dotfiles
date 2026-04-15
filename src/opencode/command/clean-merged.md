---
name: clean-merged
description: Remove all worktrees and branches that have been fully merged into the base branch
---

Usage: /clean-merged

Remove all worktrees whose branches are fully merged into the base branch. No confirmation needed — merged branches are safe to remove.

Load the **git-worktree-workflow** and **git-workflows** skills in parallel.

1. Gather state (run in parallel):
   - `git fetch origin`
   - `git worktree list --porcelain` to get all worktree paths and branches
   - Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

2. Identify merged branches:
   - Run `git branch --merged <base-branch>` to find branches fully merged into the base branch
   - Cross-reference with the worktree list to find worktrees on merged branches
   - Exclude the main working tree and the current directory

3. Remove each merged worktree and its branch sequentially:
   - If the current directory is inside a worktree being removed, skip it and warn the user
   - `git worktree remove <path>`
   - `git branch -d <branch-name>`

4. Run `git worktree prune` to clean stale references

5. Report a summary:
   - Worktrees removed and branches deleted
   - Worktrees skipped and why

Important:
- Never remove the main working tree
- Never remove the current working directory — warn and skip
