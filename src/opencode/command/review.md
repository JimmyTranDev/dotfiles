---
name: review
description: Review the diff between the current branch and the base branch (develop or main)
---

Usage: /review

Review the diff between the current branch and the base branch, then provide feedback:

1. Determine the base branch:
   - Check if `develop` branch exists locally or as `origin/develop` — if so, use it as the base
   - Otherwise, fall back to `main` (or `origin/main`)
   - If neither exists, notify the user and stop

2. Get the diff (run these git commands in parallel):
   - Run `git diff <base-branch>...HEAD` to get the changes between the base and the current branch tip
   - Run `git log --oneline <base-branch>..HEAD` to see the commits on this branch

3. Analyze the diff and provide a review covering:
   - **Summary**: What the branch does overall (1-3 sentences)
   - **Changes**: List of files changed with brief descriptions
   - **Issues**: Any bugs, logic errors, or problems found
   - **Suggestions**: Improvements for code quality, readability, or performance
   - **Security**: Flag any potential security concerns (secrets, injection, auth issues)

4. Load applicable skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Skills to load:
   - **code-logic-checker**: Load if the diff contains complex business logic or state management to verify logical correctness

   Agents to delegate to (launch all applicable agents in parallel — they analyze the same diff independently):
   - **reviewer**: Catches bugs, design issues, and provides actionable feedback on the diff
   - **auditor**: Scans for security issues if the diff touches authentication, authorization, data handling, or sensitive flows
   - **optimizer**: Identifies performance concerns if the diff introduces potentially expensive operations

Keep the review concise and actionable. Focus on what matters most.

5. Present actionable follow-ups to the user:
   - If issues or suggestions are found, list them with severity and estimated effort
   - Use the question tool with `multiple: true` to ask the user which items to address
   - For each selected item, delegate to the appropriate agent to fix it (e.g., **fixer** for bugs, **optimizer** for performance, **auditor** for security)
