---
name: merge
description: Merge the current worktree's PR, then delete the worktree and branch
---

Merge the pull request for the current branch, then clean up the worktree and branch.

1. Verify the current directory is a worktree (not the main working tree):
   - Run `git worktree list` and confirm the current directory is listed as a worktree under `~/Programming/wcreated/`
   - If the current directory is the main working tree, notify the user and stop

2. Check for uncommitted changes:
   - Run `git status --porcelain`
   - If there are uncommitted changes, warn the user and ask whether to proceed or abort

3. Identify the PR for the current branch:
   - Run `gh pr view --json number,title,url,state,mergeable,mergeStateStatus,reviewDecision`
   - If no PR exists for this branch, notify the user and stop
   - If the PR is already merged or closed, notify the user and skip to step 5

4. Merge the PR:
   - Run `gh pr merge --merge --delete-branch` to merge the PR and delete the remote branch
   - If the merge fails, report the error and stop

5. Navigate out of the worktree before removal:
   - Determine the main working tree path from `git worktree list` (first entry)
   - Instruct the user to `cd` to the main working tree since the current directory will be removed

6. Remove the worktree and local branch:
   - Capture the current branch name and worktree path before removal
   - Run `git worktree remove <worktree-path>`
   - Run `git branch -d <branch-name>` (use `-D` if the branch was not fully merged)
   - Run `git worktree prune` to clean stale references

7. Report a summary:
   - PR merge status (title, number, URL)
   - Worktree and branch that were removed

Important:
- Never remove the main working tree
- Always check for uncommitted changes before proceeding
- If any step fails, report the error clearly and stop
