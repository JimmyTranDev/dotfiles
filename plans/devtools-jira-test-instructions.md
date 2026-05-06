---
todoist: https://app.todoist.com/app/task/generate-testing-instruction-comment-upsert-command-for-jira-6gXMmpGQcgXFhF9M
---

# Create /jira-test-instructions Command

## Overview

Create a new OpenCode command that analyzes the current branch's code changes and any spec files, generates human-readable testing instructions, and upserts them as a comment on the associated Jira ticket. This automates the QA handoff step.

## Architecture

- New command file: `src/opencode/command/jira-test-instructions.md`
- Uses existing `acli` tool for Jira interaction (already available via `tool-acli` skill)
- Analyzes the current branch diff and any spec files in `plans/`

## Data flow

1. Determine the Jira ticket key from branch name (e.g., `feature/PROJ-123-foo` -> `PROJ-123`) or from `$ARGUMENTS`
2. Compute the diff: `git diff <base-branch>...HEAD`
3. Read any relevant spec files in `plans/`
4. Generate testing instructions covering: setup steps, feature verification steps, edge cases to test, regression checks
5. Search existing Jira comments for a testing instruction comment (by marker text)
6. If found, update it. If not, create a new comment.

## Tasks

1. **Load `tool-acli` skill** to understand acli comment commands (small)

2. **Create `src/opencode/command/jira-test-instructions.md`** (large)
   - Frontmatter: name `jira-test-instructions`, description
   - Accept `$ARGUMENTS` as optional Jira ticket key or URL
   - Detect ticket key from branch name if not provided
   - Determine base branch using git-workflows skill
   - Analyze diff and specs to generate testing instructions
   - Format as structured markdown with numbered steps
   - Include a marker line (e.g., `<!-- opencode:test-instructions -->`) to enable upsert
   - Use `acli` to list comments, find existing marker, update or create
   - Complexity: large
   - Sequential: depends on task 1

## API contracts

Testing instruction comment format:
```markdown
<!-- opencode:test-instructions -->
## Testing Instructions

### Prerequisites
- <setup steps>

### Test Cases
1. **<scenario>**: <steps to verify>
2. ...

### Edge Cases
- <edge case to check>

### Regression
- <areas to verify didn't break>
```

## State changes

No new state. Uses existing Jira comments.

## Edge cases

- No Jira ticket key found in branch name: ask the user
- Jira ticket doesn't exist or no access: report error
- Very large diff: summarize by module rather than file-by-file
- No spec files: generate instructions from diff alone
- `acli` not authenticated: notify user to run `acli login`

## Testing approach

- Manual: run on a branch with Jira ticket, verify comment appears
- No automated tests (command file is markdown instructions)

## Open questions

- **Decision:** Show generated instructions in chat and get user confirmation before posting to Jira.
- **Conventions:** What `acli` command format is used for upserting comments? Need to verify if `acli jira comment update` exists or if delete+create is needed.
