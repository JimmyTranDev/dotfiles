---
name: comments
description: Fetch PR review comments, let the user select which to fix, and implement the selected fixes
---

Fetch all review comments from the current branch's pull request, identify comments that request specific code changes, and implement the fixes.

1. Get the pull request and current user in parallel:
   - Run `gh pr view --json number,title,url,reviewDecision` to get the PR associated with the current branch
   - Run `gh api user --jq '.login'` to get the current user's login (needed for filtering in step 3)
   - If no PR exists for this branch, notify the user and stop

2. Fetch all review comments in parallel:
   - Run `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments` to get inline review comments
   - Run `gh pr view {pr_number} --json reviews --jq '.reviews[]'` to get top-level review comments
   - Collect all comments including author, body, path, line, and in_reply_to fields

3. Filter for valid comments that request code changes:
   - **Valid**: Comments that request a specific code change (e.g., rename a variable, fix a bug, change logic, add error handling, remove unused code, update an implementation)
   - **Invalid**: Comments that are questions, praise, acknowledgments, approvals, general discussion, or observations without a clear change request
   - Skip comments authored by the current user (fetched in step 1)
   - Skip comments that are replies to other comments (follow-up discussion) unless they contain a distinct code change request

4. Present the filtered comments and let the user select which to fix:
   - Display each valid comment with a number, the file path, line number, author, and a brief summary of the requested change
   - Ask the user which comments to fix using the question tool with `multiple: true` so they can select one or more
   - Include an "All comments" option as the first choice for convenience
   - Only proceed with the comments the user selects

5. Implement the selected fixes:
   - For each selected comment, locate the referenced file and line
   - Understand the requested change in context of the surrounding code
   - Apply the fix using the appropriate approach

6. Load skills and delegate to agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Skills to load (load all applicable in a single parallel batch before applying fixes):
   - **follower**: Learn codebase conventions before applying any fixes
   - **logic-checker**: Load if any fix involves business logic or conditional flows to verify correctness

   Agents to delegate to:
   - **fixer**: Launch multiple fixer agents in parallel for independent fixes that affect different files or non-overlapping code regions
   - **reviewer**: Use after all fixes are applied to verify nothing was broken (sequential — depends on fixer output)

7. After all fixes are applied:
   - Run `git diff` to show the user all changes made
   - Summarize which comments were addressed and what was changed
   - Commit the changes using the `git-workflows` skill commit format
