---
name: specify-comments
description: Fetch unresolved PR review comments and provide a clear summary and explanation of what each reviewer is asking for and write spec to `spec/comments/`
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

3. Filter and classify comments:
   - Skip comments authored by the current user
   - Skip comments that are pure praise, acknowledgments, approvals, or automated bot messages
   - Skip comments that are replies to other comments (follow-up discussion) unless they contain a distinct change request
   - Classify each remaining comment as:
     - **Change request**: requests a specific code change (rename, fix, add error handling, remove unused code, update implementation)
     - **Question/concern**: raises an issue but doesn't specify an exact change
     - **Suggestion**: optional improvement, not blocking

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
   - For change requests, include a concrete description of what code change is needed so a `/fix` or `/implement` command can act on it

6. Write findings to a spec file:
   - Create the `spec/comments/` directory if it doesn't exist
   - Use the PR number and branch name as the filename in kebab-case (e.g., `spec/comments/pr-123-feature-branch.md`). If a file with the same name already exists, append a timestamp suffix to avoid overwriting
   - Write the full organized comment summary from steps 4 and 5 to the file
   - Print a brief summary to chat: the file path, total number of unresolved comments, and the top 3 most important items
