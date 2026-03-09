---
name: review
description: Review the diff between the current branch and the base branch (develop or main)
---

Review the diff between the current branch and the base branch, then provide feedback:

1. Determine the base branch:
   - Check if `develop` branch exists locally or as `origin/develop` — if so, use it as the base
   - Otherwise, fall back to `main` (or `origin/main`)
   - If neither exists, notify the user and stop

2. Get the diff:
   - Run `git diff <base-branch>...HEAD` to get the changes between the base and the current branch tip
   - Also run `git log --oneline <base-branch>..HEAD` to see the commits on this branch

3. Analyze the diff and provide a review covering:
   - **Summary**: What the branch does overall (1-3 sentences)
   - **Changes**: List of files changed with brief descriptions
   - **Issues**: Any bugs, logic errors, or problems found
   - **Suggestions**: Improvements for code quality, readability, or performance
   - **Security**: Flag any potential security concerns (secrets, injection, auth issues)

4. Delegate to specialized agents where applicable:
   - **reviewer**: Use to catch bugs, design issues, and provide actionable feedback on the diff
   - **auditor**: Use if the diff touches authentication, authorization, data handling, or sensitive flows
   - **logic-checker**: Use if the diff contains complex business logic or state management to verify logical correctness
   - **optimizer**: Use if the diff introduces potentially expensive operations or performance-sensitive code

Keep the review concise and actionable. Focus on what matters most.
