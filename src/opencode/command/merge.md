---
name: merge
description: List mergeable PRs authored by you, let the user select which to merge, and clean up worktrees
---

List your open, non-draft PRs that have passing checks and approvals, let the user select which to merge, then clean up associated worktrees and branches.

1. Fetch the current user and list eligible PRs in parallel:
   - Run `gh api user --jq '.login'` to get the current user's login
   - Run `gh pr list --author @me --state open --json number,title,url,headRefName,isDraft,reviewDecision,statusCheckRollup` to list all open PRs authored by the user

2. Filter for mergeable PRs:
   - Exclude draft PRs (`isDraft: true`)
   - Exclude PRs without approval (`reviewDecision` must be `APPROVED`)
   - Exclude PRs with failing or pending checks (`statusCheckRollup` — all checks must have `conclusion: SUCCESS`)
   - If no PRs pass the filter, report why each was excluded (draft, missing approval, failing checks) and stop

3. Present eligible PRs and let the user select which to merge:
   - Display each PR with its number, title, branch name, and URL
   - Ask the user which PRs to merge using the question tool with `multiple: true`
   - Include a "Merge all" option as the first choice for convenience

4. For each selected PR, merge and clean up sequentially:

   a. Merge the PR:
      - Run `gh pr merge <number> --merge --delete-branch`
      - If the merge fails, report the error and continue to the next PR

   b. Clean up the local worktree and branch if they exist:
      - Run `git worktree list` to check if a worktree exists for this PR's branch
      - If a worktree exists at `~/Programming/wcreated/<branch-name>`:
        - Run `git worktree remove <worktree-path>`
      - Run `git branch -d <branch-name>` to delete the local branch (use `-D` if needed)
      - Run `git worktree prune` to clean stale references

5. Report a summary:
   - List each merged PR (number, title, URL)
   - List any PRs that failed to merge and why
   - List worktrees and branches that were cleaned up

Important:
- Never remove the main working tree
- If the current directory is inside a worktree being removed, instruct the user to `cd` out first
- Continue merging remaining PRs even if one fails
