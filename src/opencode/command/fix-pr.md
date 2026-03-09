---
name: fix-pr
description: Fetch PR review comments, validate which request code changes, and fix them
---

Fetch all review comments from the current branch's pull request, identify comments that request specific code changes, and implement the fixes.

1. Get the pull request for the current branch:
   - Run `gh pr view --json number,title,url,reviewDecision` to get the PR associated with the current branch
   - If no PR exists for this branch, notify the user and stop

2. Fetch all review comments:
   - Run `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments` to get inline review comments
   - Run `gh pr view {pr_number} --json reviews --jq '.reviews[]'` to get top-level review comments
   - Collect all comments including author, body, path, line, and in_reply_to fields

3. Filter for valid comments that request code changes:
   - **Valid**: Comments that request a specific code change (e.g., rename a variable, fix a bug, change logic, add error handling, remove unused code, update an implementation)
   - **Invalid**: Comments that are questions, praise, acknowledgments, approvals, general discussion, or observations without a clear change request
   - Skip comments authored by the current user (`gh api user --jq '.login'`)
   - Skip comments that are replies to other comments (follow-up discussion) unless they contain a distinct code change request
   - Present the filtered list of valid comments to the user before proceeding

4. Implement the fixes:
   - For each valid comment, locate the referenced file and line
   - Understand the requested change in context of the surrounding code
   - Apply the fix using the appropriate approach

5. Load relevant skills and delegate to specialized agents where applicable:

   Skills to load:
   - **convention-matcher**: Load first to learn codebase conventions before applying any fixes
   - **logic-checker**: Load if any fix involves business logic or conditional flows to verify correctness

   Agents to delegate to:
   - **fixer**: Use for each code change request to apply minimal, surgical fixes
   - **reviewer**: Use after all fixes are applied to verify nothing was broken

6. After all fixes are applied:
   - Run `git diff` to show the user all changes made
   - Summarize which comments were addressed and what was changed
   - Commit the changes using the `git-workflows` skill commit format
