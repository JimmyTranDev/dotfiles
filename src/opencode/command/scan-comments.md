---
name: scan-comments
description: Fetch unresolved PR review comments and provide a clear summary and explanation of what each reviewer is asking for
---

Fetch all unresolved review comments from the current branch's pull request and present a clear, organized explanation of what each reviewer is requesting.

1. Get the pull request and current user in parallel:
   - Run `gh pr view --json number,title,url,headRefName` to get the PR associated with the current branch
   - Run `gh api user --jq '.login'` to get the current user's login (needed for filtering in step 3)
   - If no PR exists for this branch, notify the user and stop

2. Fetch unresolved review comments:
   - Use `gh api graphql` to query `pullRequest.reviewThreads` — only include threads where `isResolved: false`
   - For each unresolved thread, collect: file path, line number, all comments in the thread (author, body, createdAt), and the diff hunk for context
   - Also run `gh pr view {pr_number} --json reviews --jq '.reviews[]'` to get top-level review comments that may contain feedback

3. Filter out noise:
   - Skip comments authored by the current user
   - Skip comments that are pure praise, acknowledgments, approvals, or automated bot messages
   - Keep all comments that contain questions, concerns, change requests, or suggestions

4. Present each unresolved comment with a clear explanation:
   - For each comment, display:
     - **File & location**: path and line number
     - **Author**: who left the comment
     - **What they said**: the original comment text (brief quote)
     - **What they're asking for**: a plain-language explanation of what the reviewer wants — translate jargon, clarify implicit expectations, and explain _why_ the reviewer likely raised this concern
     - **Thread context**: if there are follow-up replies in the thread, summarize the discussion progression
   - Order comments by file path, then by line number within each file

5. At the end, provide a high-level summary:
   - Total number of unresolved comments
   - Group comments by theme (e.g., "naming concerns", "error handling gaps", "performance suggestions", "logic issues")
   - Mention if any comments appear to be blocking vs. nice-to-have based on tone and phrasing
