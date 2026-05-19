---
name: pr-combined
description: Create a combined PR merging multiple worktree feature branches for test/deploy testing
---

Usage: /pr-combined [branch names or "all"]

$ARGUMENTS

Create a temporary combined PR that merges multiple feature branches together for integration testing or test deployment.

## Workflow

1. Load the **git-worktree-workflow** and **git-workflows** skills in parallel

2. Run `git-branch-info.sh` and use the `BASE_BRANCH` value

3. Determine which branches to combine:
   - If `$ARGUMENTS` lists specific branch names, use those
   - If `$ARGUMENTS` is "all", use all worktree branches with open PRs
   - If no arguments, list available worktree branches and let the user multi-select
   - Only include branches from worktrees (under `~/Programming/wcreated/`)

4. Create the combined branch:
   ```bash
   git checkout <base-branch>
   git pull origin <base-branch>
   git checkout -b combined/<date>-<short-description>
   ```

5. Merge each feature branch into the combined branch:
   - For each branch: `git merge origin/<branch-name> --no-edit`
   - If a merge conflict occurs:
     - Report which branches conflict
     - Ask the user to resolve or skip that branch
     - If skipping, reset and continue with remaining branches

6. Push and create the PR:
   ```bash
   git push -u origin combined/<date>-<short-description>
   gh pr create --title "Combined: <branches>" --body "<list of included PRs>" --label "combined-test"
   ```

7. Report:
   - Combined PR URL
   - Branches included
   - Any branches that were skipped due to conflicts

## Rules

- Combined branches are temporary — they should be deleted after testing
- Never merge the combined PR into the base branch
- The combined PR title should clearly indicate it's for testing only
- Include links to individual PRs in the body
