---
name: tutorial-implement-jira
description: Fetch a Jira ticket from the current branch and implement it one step at a time, explaining each step and pausing for questions
---

Fetch the Jira ticket for the current branch and implement the work described in it, one step at a time. Before each step, explain what you're about to do and why. After each step, show what changed and ask if the user has questions or wants to continue.

Usage: /tutorial-implement-jira

1. Verify `acli` is installed:
   - Run `command -v acli` to check if the Atlassian CLI tool is available
   - If not found, notify the user: "The `acli` (Atlassian CLI) tool is required but not installed. Install it from https://bobswift.atlassian.net/wiki/spaces/ACLI" and stop

2. Get the ticket ID from the current branch:
   - Run `git rev-parse --abbrev-ref HEAD` to get the current branch name
   - Extract the ticket ID by matching the pattern `[A-Z]+-[0-9]+` from the branch name (e.g. `BW-10257` from `BW-10257-some-feature-description`)
   - If no ticket ID can be extracted, notify the user and stop

3. Fetch the Jira ticket:
   - Run `acli jira workitem view <TICKET-ID> --fields "summary,description,status,priority,issuelinks,comment,attachment"`
   - If the ticket is not found, notify the user and stop

4. Present the ticket to the user:
   - Show the ticket key, summary, status, and description
   - If the ticket description is vague, incomplete, or ambiguous, ask the user for clarification before proceeding
   - Ask the user to confirm before proceeding with implementation

5. Break the ticket into small, logical implementation steps:
   - Each step should be a single focused change (one function, one file modification, one configuration change)
   - Order steps so each builds on the previous — the user should be able to follow the progression
   - Present the full list of steps upfront so the user sees the plan

6. Use the TodoWrite tool to create a todo for each step with a descriptive name.

7. For each step:

   a. **Explain before doing**: Describe what you're about to change, which file it's in, why this change is needed, and how it connects to the Jira ticket's requirements. If there are design decisions or tradeoffs, explain them.

   b. **Implement the change**: Make the single focused change. Keep it small enough that the user can follow along. Follow the `/implement` command workflow — load relevant skills (always include **code-follower**) and delegate to specialized agents as needed.

   c. **Show what changed**: Summarize what was modified — file path, what was added/removed/changed, and what the code does.

   d. **Mark the todo as completed**.

   e. **Pause and ask**: Stop and ask the user:
      - "Any questions about this step?"
      - "Ready for the next step, or want to go deeper into something?"
      - Do NOT proceed to the next step until the user confirms

8. If the user asks a question:
   - Answer it thoroughly — explain the why, show relevant code, connect it to the broader picture and the Jira ticket requirements
   - After answering, ask again if they're ready to continue

9. After all steps are complete:
   - Summarize everything that was changed across all steps
   - Map each change back to the Jira ticket requirements to confirm full coverage
   - Highlight the key patterns and decisions the user should remember
   - Ask if there's anything they want to revisit or understand better

Important:
- Never skip the pause between steps — the whole point is interactive, paced learning
- Never batch multiple changes into one step to "save time" — small steps are the goal
- If a step turns out to be more complex than expected, split it into sub-steps on the fly
- Adjust explanation depth based on the user's questions — if they ask basic questions, explain more fundamentals; if they ask advanced questions, go deeper
