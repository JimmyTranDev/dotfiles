---
name: pr-fix
description: Improve or fix an existing PR based on review feedback and code analysis
---

Usage: /pr-fix [$ARGUMENTS]

Address review feedback and improve the current branch's pull request. If `$ARGUMENTS` is provided, focus on those specific issues. Otherwise, gather all open review comments and fix everything.

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

4. Plan the fixes:
   - Group related issues together
   - Present a summary of what will be fixed to the user
   - Ask the user to confirm before proceeding

5. Implement the fixes:
   - Apply changes to address each issue
   - Launch **fixer** agents in parallel for independent fixes across different files

6. Verify the fixes — launch **reviewer** and **auditor** in parallel:
   - Both agents analyze the updated diff from `git diff <base-branch>...HEAD`
   - If new issues are found, fix them (max 2 iterations)

7. Stage and commit:
   - `git add -A`
   - `git commit -m "<emoji> <type>(<scope>): <description>"` using the format from the **git-workflows** skill
   - Use a commit message that describes what was fixed (e.g., `🐛 fix(auth): address pr review feedback`)

8. Push the changes:
   - `git push`
   - If the push fails, notify the user with the error details

9. Report a summary:
   - List of issues addressed
   - Commit(s) created
   - Link to the updated PR

Important:
- Do not force push unless the user explicitly requests it
- If there are merge conflicts when pushing, notify the user and stop
- If the PR has required checks failing, mention it in the summary
- Resolve inline review comments by replying with `gh api` if the fix directly addresses the comment
