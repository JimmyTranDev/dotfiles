---
name: clean-worktrees
description: Delete all worktrees and their branches, preserving main/master/develop
---

Remove all git worktrees and their associated branches, skipping protected branches.

1. Run `git worktree list` to enumerate all worktrees

2. Identify protected branches that must never be removed:
   - `main`, `master`, `develop`
   - The main working tree (first entry from `git worktree list`)

3. For each non-protected worktree:
   - Check for uncommitted changes via `git -C <path> status --porcelain`
   - If uncommitted changes exist, warn the user and list the dirty worktrees
   - Ask the user for confirmation before proceeding with removal of dirty worktrees

4. Remove confirmed worktrees:
   - Run `git worktree remove <path>` for each worktree
   - Delete the associated branch with `git branch -D <branch-name>`
   - If removal fails, report the error and continue with remaining worktrees

5. Run `git worktree prune` to clean up stale references

6. Report a summary of what was removed and what was skipped

Important:
- Never remove the main working tree
- Never remove worktrees on `main`, `master`, or `develop`
- Always warn before removing worktrees with uncommitted changes
- If no removable worktrees are found, notify the user and stop
