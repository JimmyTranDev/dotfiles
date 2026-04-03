---
name: merge
description: List mergeable PRs authored by you, let the user select which to merge, and clean up worktrees
---

List your open, non-draft PRs that have passing checks, let the user select which to merge, then clean up associated worktrees and branches.

1. Fetch the current user and list eligible PRs in parallel:
   - Run `gh api user --jq '.login'` to get the current user's login
   - Run `gh pr list --author @me --state open --json number,title,url,headRefName,isDraft,reviewDecision,statusCheckRollup` to list all open PRs authored by the user

2. Filter for mergeable PRs:
   - Exclude draft PRs (`isDraft: true`)
   - Exclude PRs with failing or pending checks (`statusCheckRollup` — all checks must have `conclusion: SUCCESS`)
   - If no PRs pass the filter, report why each was excluded (draft, failing checks) and stop

3. Present eligible PRs and let the user select which to merge:
   - Display each PR with its number, title, branch name, and URL
   - Ask the user which PRs to merge using the question tool with `multiple: true`
   - Include a "Merge all" option as the first choice for convenience

4. Process each selected PR one at a time — fully merge, fix, and clean up each PR before moving to the next. This ensures each subsequent PR sees the previous PR's changes in the base branch, reducing conflicts:

   a. Merge the PR:
      - Run `gh pr merge <number> --merge --delete-branch`
      - If the merge fails for a non-conflict reason, report the error and continue to the next PR

   b. If the merge fails due to merge conflicts, resolve and retry:
      - Load the **git-conflict-resolution** skill
      - Determine the base branch the PR targets: `gh pr view <number> --json baseRefName --jq '.baseRefName'`
      - Ensure the worktree exists for this PR's branch at `~/Programming/wcreated/<branch-name>` — if not, create it with `git worktree add ~/Programming/wcreated/<branch-name> <branch-name>`
      - In the worktree directory, fetch and merge the base branch: `git fetch origin <base-branch> && git merge origin/<base-branch>`
      - Identify conflicted files with `git diff --name-only --diff-filter=U`
      - Resolve each conflict using the **git-conflict-resolution** skill strategies — read each conflicted file, apply the correct resolution, then `git add` each resolved file
      - Commit the merge resolution: `git commit --no-edit`
      - Push the updated branch: `git push`
      - Retry the merge: `gh pr merge <number> --merge --delete-branch`
      - If the retry still fails, report the error and continue to the next PR

   c. Clean up the local worktree and branch if they exist:
      - Run `git worktree list` to check if a worktree exists for this PR's branch
      - If a worktree exists at `~/Programming/wcreated/<branch-name>`:
        - Run `git worktree remove <worktree-path>`
      - Run `git branch -d <branch-name>` to delete the local branch (use `-D` if needed)
      - Run `git worktree prune` to clean stale references

   d. Only after cleanup is complete, move to the next PR

5. Report a summary:
   - List each merged PR (number, title, URL)
   - List any PRs that failed to merge and why
   - List worktrees and branches that were cleaned up

Important:
- Never remove the main working tree
- If the current directory is inside a worktree being removed, instruct the user to `cd` out first
- Continue merging remaining PRs even if one fails
