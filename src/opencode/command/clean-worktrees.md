---
name: clean-worktrees
description: Remove stale worktrees and their branches, with safety checks for uncommitted changes
---

Remove worktrees that are no longer needed — merged branches, stale references, and orphaned directories.

Load the **worktree-workflow** skill.

1. List all worktrees and gather state in parallel:
   - `git worktree list --porcelain` to get all worktree paths and branches
   - `git branch --merged` against the base branch (use priority order from **git-workflows** skill: `develop` > `main` > `master`) to identify merged branches

2. Categorize each worktree (excluding the main working tree):
   - **Merged**: branch is fully merged into the base branch — safe to remove
   - **Unmerged with no changes**: branch is not merged but has no uncommitted changes
   - **Unmerged with changes**: branch has uncommitted or unstaged changes — requires confirmation
   - **Stale**: worktree path no longer exists on disk

3. Present the categorized list to the user:
   - Show each worktree with its path, branch name, category, and last commit message
   - Ask the user which to remove using the question tool with `multiple: true`
   - Pre-select all **merged** and **stale** worktrees as defaults
   - Include a "Remove all merged and stale" convenience option

4. For each selected worktree, remove sequentially:
   - If the worktree has uncommitted changes, ask for explicit confirmation before proceeding
   - If the current directory is inside the worktree being removed, instruct the user to `cd` out first and stop
   - Run `git worktree remove <path>` (use `--force` only if the user confirmed for dirty worktrees)
   - Delete the local branch: `git branch -d <branch-name>` (use `-D` if not fully merged and user confirmed)

5. Run `git worktree prune` to clean stale references

6. Report a summary:
   - Worktrees removed and branches deleted
   - Worktrees skipped and why (uncommitted changes, user declined)
   - Disk space freed (count of removed worktrees)

Important:
- Never remove the main working tree
- Never remove the current working directory — warn and skip
- Default to the safe option (skip) when the user declines confirmation
- Never force-delete without explicit user confirmation
