---
name: fix-pr
description: Address PR review feedback, resolve merge conflicts, and update the PR description
---

Usage: /fix-pr [$ARGUMENTS]

Address review feedback, update the PR description on GitHub, and resolve merge conflicts for the current branch's pull request. If `$ARGUMENTS` is provided, focus on those specific issues. Otherwise, gather all open review comments and fix everything.

Load the **git-workflows** skill for commit conventions.

1. Verify a PR exists for the current branch:
   - Run `gh pr view --json number,title,url,state,headRefName,baseRefName,reviewDecision`
   - If no PR exists, notify the user and stop
   - If the PR is already merged or closed, notify the user and stop

2. Gather context (run all in parallel):
   - `gh pr view --json comments,reviews,reviewRequests` to get all PR-level comments and reviews
   - `gh api repos/{owner}/{repo}/pulls/{number}/comments` to get inline review comments
   - `git diff $(gh pr view --json baseRefName -q .baseRefName)...HEAD` to see the current diff
   - `git log --oneline $(gh pr view --json baseRefName -q .baseRefName)..HEAD` to see commits on this branch

3. Analyze all feedback:
   - Parse review comments, inline code comments, and requested changes
   - Identify which comments are resolved vs unresolved
   - If `$ARGUMENTS` was provided, prioritize those issues
   - If no `$ARGUMENTS` and no unresolved comments exist, run **reviewer** and **auditor** in parallel on the diff to find improvements
   - For ambiguous review comments, ask the user what the reviewer meant before attempting a fix

4. For each unresolved comment, present it and ask the user:
   - **Fix it**: Apply the suggestion
   - **Skip it**: Prompt for a reason, then append to `comments.md` in the project root with format: `## PR #<number> - <date>` / `### <comment summary>` / `<reason for skipping>`
   - **Clarify it**: Ask the user what the reviewer meant before deciding

4. Check for merge conflicts:
   - Run `git fetch origin` then `git merge origin/<base-branch> --no-commit --no-ff` to test for conflicts
   - If conflicts exist:
     - List all conflicted files
     - Resolve each conflict by analyzing both sides and choosing the correct resolution
     - Stage resolved files with `git add <file>`
     - Complete the merge with `git commit -m "🔨 refactor: resolve merge conflicts with <base-branch>"`
   - If no conflicts, abort the test merge with `git merge --abort`

5. Plan the fixes:
   - Group related issues together
   - Present a summary of what will be fixed to the user
   - Ask the user to confirm before proceeding

6. Implement the fixes:
   - Apply changes to address each issue
   - Launch **fixer** agents in parallel for independent fixes across different files

7. Verify the fixes — launch **reviewer** and **auditor** in parallel:
   - Both agents analyze the updated diff from `git diff <base-branch>...HEAD`
   - If new issues are found, fix them (max 2 iterations)

8. Stage and commit:
   - `git add -A`
   - `git commit -m "<emoji> <type>(<scope>): <description>"` using the format from the **git-workflows** skill
   - Use a commit message that describes what was fixed (e.g., `🐛 fix(auth): address pr review feedback`)

9. Push the changes:
   - `git push`
   - If the push fails, notify the user with the error details

10. Update the PR description on GitHub:
    - Generate an updated PR body summarizing all commits on the branch: `git log --oneline $(gh pr view --json baseRefName -q .baseRefName)..HEAD`
    - Include a summary section describing the overall changes
    - Update with `gh pr edit <number> --body "<updated body>"`

11. Report a summary:
    - List of issues addressed
    - Whether merge conflicts were resolved
    - Commit(s) created
    - Link to the updated PR

Important:
- Do not force push unless the user explicitly requests it
- If the push fails due to remote changes, pull and retry once before notifying the user
- If the PR has required checks failing, mention it in the summary
- After fixing a comment, draft a reply explaining what was done and show it to the user for approval before posting via `gh api`
- Create `comments.md` with a `# PR Comment Decisions` header if it doesn't exist yet
