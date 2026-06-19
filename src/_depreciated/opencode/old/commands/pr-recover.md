---
name: pr-recover
description: Recover a PR by recreating its worktree from the remote branch
---

Usage: /pr-recover [PR URL or number]

$ARGUMENTS

Recover a PR whose local worktree was deleted by recreating it from the remote branch.

## Workflow

1. Load the **git-worktree-workflow** and **git-workflows** skills in parallel

2. Determine which PR(s) to recover:
   - If `$ARGUMENTS` contains a PR URL or number, recover that specific PR
   - If no arguments, list all open PRs missing local worktrees:
     - `gh pr list --author @me --state open --json headRefName,url,title`
     - `git worktree list --porcelain` to get existing worktree branches
     - Show PRs whose branch is not in any local worktree
     - Let the user select which to recover using the question tool

3. For each PR to recover:
   - Fetch the latest remote: `git fetch origin <branch-name>`
   - Create the worktree: `git worktree add ~/Programming/wcreated/<branch-name> <branch-name>`
   - Verify the worktree is set up correctly

4. Report: "Recovered N worktrees: [branch-list with PR URLs]"

## Edge Cases

- If the remote branch was force-pushed or rebased, the worktree will still be created from the latest remote state
- If the branch no longer exists on remote, notify the user and skip
- If a worktree already exists for that branch, notify and skip
