---
name: implement-learnings
description: Extract bugs, gotchas, and pitfalls from PR review comments and append them to LEARNINGS.md
---

Fetch all review comments from the current branch's pull request, extract actionable learnings (bugs, gotchas, pitfalls, anti-patterns), and append them to `LEARNINGS.md` in the project root.

1. Get the pull request:
   - Run `gh pr view --json number,title,url,headRefName` to get the PR associated with the current branch
   - If no PR exists for this branch, notify the user and stop

2. Fetch all review comments (resolved and unresolved) in parallel:
   - Use `gh api graphql` to query `pullRequest.reviewThreads` — collect all threads regardless of resolution status, since resolved comments still contain valuable learnings
   - Run `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments` to get inline review comments
   - Run `gh pr view {pr_number} --json reviews --jq '.reviews[]'` to get top-level review comments
   - Collect all comments including author, body, path, line, and thread context

3. Filter for comments that contain learnings:
   - **Keep**: Comments that identify bugs, gotchas, pitfalls, anti-patterns, missed edge cases, security concerns, performance issues, or common mistakes
   - **Skip**: Comments that are pure style preferences, praise, acknowledgments, approvals, automated bot messages, or questions without a clear lesson

4. Read existing `LEARNINGS.md` if it exists:
   - Parse existing entries to avoid duplicating learnings already recorded
   - If the file doesn't exist, it will be created in step 6

5. Show the user what will be added:
   - Display each new learning entry before writing
   - Each entry format:
     ```
     ### <Short title>
     - **Location**: <file path and line number from the PR>
     - **PR**: <PR URL>
     - **Pitfall**: <concise description of the bug, gotcha, or anti-pattern>
     - **Avoidance**: <how to avoid this in the future>
     ```

6. Append new entries to `LEARNINGS.md`:
   - Add a section header `## Learnings from PR #<number> — <PR title>` if there are new entries
   - Append all new learning entries under this section
   - Show the final diff of changes made to `LEARNINGS.md` using `git diff`
