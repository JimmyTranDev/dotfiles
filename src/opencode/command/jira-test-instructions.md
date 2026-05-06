---
name: jira-test-instructions
description: Generate testing instructions from branch changes and upsert as a Jira comment
---

Usage: /jira-test-instructions [JIRA-KEY or Jira URL]

$ARGUMENTS

Generate human-readable testing instructions from the current branch's code changes and any spec files, then upsert them as a comment on the associated Jira ticket.

## Workflow

1. Load the **tool-acli** and **git-workflows** skills in parallel

2. Determine the Jira ticket key:
   - If `$ARGUMENTS` contains a Jira key (e.g., `PROJ-123`) or URL, extract the key
   - Otherwise, extract from the current branch name (e.g., `feature/PROJ-123-foo` -> `PROJ-123`)
   - If no key is found, ask the user for the ticket key

3. Gather context in parallel:
   - Run `git-branch-info.sh` to get the base branch
   - Read any spec files in `plans/` that reference the ticket key

4. Compute the diff: `git diff <base-branch>...HEAD`

5. Analyze the diff and spec files to generate testing instructions covering:
   - **Prerequisites**: setup steps, environment requirements, test data needed
   - **Test Cases**: numbered steps to verify the feature works correctly
   - **Edge Cases**: boundary conditions, error scenarios, unusual inputs to test
   - **Regression**: areas that may have been affected and should be verified

6. Format the instructions using this template:

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

7. Show the generated instructions in chat and ask the user for confirmation before posting to Jira

8. After confirmation, upsert the comment on Jira:
   - List existing comments: `acli jira workitem comment list --key "<JIRA-KEY>"`
   - Search for a comment containing the marker `<!-- opencode:test-instructions -->`
   - If found, update it: write the new instructions to a temp file and run `acli jira workitem comment update --key "<JIRA-KEY>" --edit-last --body-file <tempfile>`
   - If not found, create a new comment: `acli jira workitem comment create --key "<JIRA-KEY>" --body-file <tempfile>`
   - Clean up the temp file

## Edge Cases

- Very large diff: summarize by module rather than listing every file change
- No spec files: generate instructions from diff alone
- `acli` not authenticated: notify user to run `acli auth` and stop
- Jira ticket not found or no access: report error and stop
