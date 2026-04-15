---
name: clean-all
description: Remove all worktrees and their branches with confirmation
---

Usage: /clean-all

Remove all worktrees and their local branches. Asks for confirmation before proceeding since this includes unmerged branches.

Load the **git-worktree-workflow** and **git-workflows** skills in parallel.

1. Gather state (run in parallel):
   - `git fetch origin`
   - `git worktree list --porcelain` to get all worktree paths and branches
   - Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

2. Categorize each worktree (excluding the main working tree):
   - **Merged**: branch is fully merged into the base branch
   - **Unmerged**: branch is not fully merged
   - **Stale**: worktree path no longer exists on disk

3. Present the full list to the user:
   - Show each worktree with its path, branch name, category, and last commit message
   - Ask the user to confirm removal of all listed worktrees using the question tool

4. Remove each worktree and its branch sequentially:
   - If the current directory is inside a worktree being removed, skip it and warn the user
   - `git worktree remove <path>` (use `--force` for worktrees with uncommitted changes)
   - `git branch -D <branch-name>`

5. Run `git worktree prune` to clean stale references

6. Report a summary:
   - Worktrees removed and branches deleted
   - Worktrees skipped and why

Important:
- Never remove the main working tree
- Never remove the current working directory — warn and skip
- Require explicit confirmation before removing unmerged branches
