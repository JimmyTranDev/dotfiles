---
name: specify-jira
description: Specify skill for Jira ticket analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`jira-` (followed by ticket ID, e.g., `jira-BW-10257`)

## Skills to Load

None required (domain skills loaded based on project type).

## Agents to Launch

None specified.

## Analysis Categories

### Prerequisites

- Verify `acli` is installed: `command -v acli`
- Extract ticket ID from branch name using pattern `[A-Z]+-[0-9]+`

### Ticket Fetching

- `acli jira workitem view <TICKET-ID> --fields "summary,description,status,priority,issuelinks,comment,attachment"`
- If ticket has linked issues, fetch those for additional context

### Requirement Analysis

- Parse ticket summary, description, and comments to extract full scope
- Identify acceptance criteria, constraints, and technical details
- If description is vague or ambiguous, ask for clarification

### Codebase Mapping

- Identify which files, modules, and layers the work touches
- Determine new code vs existing code modifications
- Identify inputs, outputs, and side effects
- Note dependencies between tasks

### Spec Output Sections

- **Ticket**: Key, summary, status, priority, Jira link
- **Overview**: 2-3 sentence summary of what to build and why
- **Architecture**: How changes fit into existing codebase
- **Tasks**: Ordered list with file path, changes needed, dependencies, complexity, parallelizability
- **API contracts**: New endpoints, function signatures, type definitions
- **Edge cases**: Known edge cases, error conditions, boundary behaviors
- **Testing approach**: What tests are needed and what they verify
- **Open questions**: Ambiguities grouped by requirements, architecture, scope, risks

## Severity Classification

Not applicable — this is implementation planning, not issue finding.

## Scope Overrides

Scope is always derived from the current branch's Jira ticket. If no ticket ID can be extracted from the branch name, notify and stop.
