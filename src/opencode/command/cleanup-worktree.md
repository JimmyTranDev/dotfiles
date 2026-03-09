---
name: cleanup-worktree
description: List and remove stale git worktrees and their associated branches
---

Usage: /cleanup-worktree [worktree-name]

Find and clean up git worktrees that are no longer needed.

$ARGUMENTS

Current worktrees:
!`git worktree list`

1. **List all worktrees**:
   - Run `git worktree list` to show all active worktrees
   - For each worktree (excluding the main working tree), check if it has uncommitted changes via `git -C <path> status --porcelain`
   - Display a summary: worktree path, branch name, whether it has uncommitted changes

2. **Determine what to clean**:
   - If the user specifies a worktree name (`$1`), target only that worktree
   - If no argument is given, present the list and ask the user which worktrees to remove
   - Never remove the main working tree
   - If the targeted worktree path is the current working directory, refuse to remove it and explain why

3. **Safety checks** before removal:
   - If a targeted worktree has uncommitted or unstaged changes, warn the user and ask for confirmation before proceeding
   - If the worktree path does not exist on disk, use `git worktree prune` to clean up stale entries

4. **Remove worktrees**:
   - Capture the branch name from `git worktree list` output before removing the worktree
   - For each confirmed worktree, run `git worktree remove <path>`
   - If removal fails due to untracked or modified files and the user confirms, use `git worktree remove --force <path>`
   - After removal, delete the associated branch with `git branch -d <branch-name>`
   - If branch deletion fails because it is not fully merged, warn the user and ask if they want to force delete with `git branch -D <branch-name>`

5. **Final cleanup**:
   - Run `git worktree prune` to remove any stale worktree references
   - Run `git worktree list` to show the updated state
   - Summarize what was removed

Important:
- Never remove the main working tree or the current working directory
- Always warn before removing worktrees with uncommitted changes
- Always warn before force-deleting unmerged branches
- Default to the safe option (skip) if the user declines confirmation
