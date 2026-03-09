---
name: jira
description: Fetch a Jira ticket and implement the described task
---

Fetch the Jira ticket for the current branch and implement the work described in it.

Usage: /jira

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

5. Implement the task:
   - Use the ticket summary and description as the implementation prompt
   - Follow the same workflow as the `/implement` command:
     1. Analyze the ticket to categorize the type of work
      2. Run the **convention-matcher** agent to learn codebase conventions
     3. Implement the changes, delegating to the appropriate specialized agents
     4. Run the **reviewer** agent on the completed implementation
     5. If the reviewer surfaces problems, use the **fixer** agent to address them
