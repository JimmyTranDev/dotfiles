---
name: specify-jira
description: Fetch the Jira ticket for the current branch and generate an implementation spec in spec/
---

Usage: /specify-jira

Fetch the Jira ticket associated with the current branch, analyze the codebase to understand what needs to change, and produce a detailed implementation spec file in `spec/jira/`.

1. Verify `acli` is installed:
   - Run `command -v acli` to check if the Atlassian CLI tool is available
   - If not found, notify the user: "The `acli` (Atlassian CLI) tool is required but not installed. Install it from https://bobswift.atlassian.net/wiki/spaces/ACLI" and stop

2. Get the ticket ID from the current branch:
   - Run `git rev-parse --abbrev-ref HEAD` to get the current branch name
   - Extract the ticket ID by matching the pattern `[A-Z]+-[0-9]+` from the branch name (e.g. `BW-10257` from `BW-10257-some-feature-description`)
   - If no ticket ID can be extracted, notify the user and stop

3. Fetch the Jira ticket and understand the project in parallel:
   - Run `acli jira workitem view <TICKET-ID> --fields "summary,description,status,priority,issuelinks,comment,attachment"`
   - Explore the project structure, entry points, and key modules to understand the tech stack and architecture
   - Run `git log --oneline -30` to understand recent development direction
   - Read key config files or AGENTS.md to understand conventions and constraints
   - If the ticket is not found, notify the user and stop

4. Analyze the ticket requirements:
   - Parse the ticket summary, description, and comments to extract the full scope of work
   - If the ticket has linked issues, fetch those for additional context
   - Identify acceptance criteria, constraints, and any technical details mentioned in the ticket
   - If the ticket description is vague, incomplete, or ambiguous, ask the user for clarification before proceeding

5. Map the ticket requirements to the codebase:
   - Identify which files, modules, and layers the work touches
   - Determine what new code needs to be created vs what existing code needs modification
   - Identify the inputs, outputs, and side effects of the changes
   - Note any dependencies between tasks

6. Write the spec file:
   - Create `spec/` if it doesn't exist
   - Write to `spec/jira-<TICKET-ID>.md` (e.g., `spec/jira-BW-10257.md`)
   - Include these sections:

   **Ticket**: ticket key, summary, status, priority, and link to the Jira ticket
   **Overview**: 2-3 sentence summary of what needs to be built and why
   **Architecture**: how the changes fit into the existing codebase — which layers are touched, where new code goes, how it connects to existing modules
   **Tasks**: ordered list of every file to create or modify, with:
     - File path
     - What changes are needed
     - Dependencies on other tasks
     - Estimated complexity (small/medium/large)
     - Whether the task can run in parallel with others
   **API contracts**: if applicable — new endpoints, function signatures, type definitions, or interfaces
   **Edge cases**: known edge cases, error conditions, and boundary behaviors
   **Testing approach**: what tests are needed and what behaviors they verify
   **Open questions**: ambiguities from the ticket that need answers before implementation, grouped by requirements, architecture, scope, and risks

7. Print a summary to chat:
   - Ticket key and summary
   - Spec file path
   - Total number of tasks and estimated overall complexity
   - Top open questions that need answers before starting
   - Suggest running `/implement-jira` or `/implement spec/jira-<TICKET-ID>.md` to begin implementation
