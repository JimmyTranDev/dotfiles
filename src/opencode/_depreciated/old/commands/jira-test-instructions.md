---
name: jira-test-instructions
description: Generate testing instructions from branch changes and upsert as a Jira comment
---

Usage: /jira-test-instructions [JIRA-KEY...] [--file <output-path>]

$ARGUMENTS

Generate human-readable testing instructions from code changes associated with one or more Jira tickets, then optionally upsert them as comments on the Jira tickets.

## Workflow

1. Load the **tool-acli** and **git-workflows** skills in parallel

2. Determine the Jira ticket key(s):
   - Parse `$ARGUMENTS` to extract all Jira keys (e.g., `BW-123 BW-456 BW-789`) or URLs
   - If no keys found in arguments, extract from the current branch name (e.g., `feature/PROJ-123-foo` -> `PROJ-123`)
   - If no key is found, ask the user for the ticket key(s)

3. For each ticket, gather context in parallel:
   - Find related PRs: `gh pr list --search "<TICKET>" --json number,title,headRefName,url`
   - Find related commits: `git log --all --grep="<TICKET>" --oneline`
   - Read any spec files in `plans/` that reference the ticket key

4. For each ticket, compute diffs:
   - For PRs: `gh pr diff <number>`
   - For branch-based (single ticket, no PRs): `git diff <base-branch>...HEAD`

5. Analyze all diffs and spec files to generate testing instructions covering:
   - **Prerequisites**: setup steps, environment requirements, test data needed
   - **Test Cases**: numbered steps to verify the feature works correctly
   - **Edge Cases**: boundary conditions, error scenarios, unusual inputs to test
   - **Regression**: areas that may have been affected and should be verified

6. Format the instructions. For multiple tickets, group by ticket:

```
<!-- opencode:test-instructions -->
## Testing Instructions

### TICKET-123: <ticket summary>

#### Prerequisites
- <setup steps>

#### Test Cases
1. **<scenario>**: <steps to verify>
2. ...

#### Edge Cases
- <edge case to check>

#### Regression
- <areas to verify didn't break>

### TICKET-456: <ticket summary>
...
```

7. Write output to a file:
   - If `--file <path>` is specified, use that path
   - Otherwise, write to `testing-instructions-YYYY-MM-DD.txt` in the current directory
   - Use pure plain text format (no markdown syntax — no #, *, `, etc.)
   - Use dashes for lists, ALL CAPS for headers, and indentation for structure

8. Show the generated instructions in chat and ask the user for confirmation before posting to Jira

9. After confirmation, for each ticket, upsert the comment on Jira:
   - List existing comments: `acli jira workitem comment list --key "<JIRA-KEY>"`
   - Search for a comment containing the marker `<!-- opencode:test-instructions -->`
   - If found, update it: write the new instructions to a temp file and run `acli jira workitem comment update --key "<JIRA-KEY>" --edit-last --body-file <tempfile>`
   - If not found, create a new comment: `acli jira workitem comment create --key "<JIRA-KEY>" --body-file <tempfile>`
   - Clean up the temp file

10. After successfully posting to Jira, ask the user if they want to delete the local instructions file. If yes, remove it.

## Edge Cases

- Very large diff: summarize by module rather than listing every file change
- No spec files: generate instructions from diff alone
- `acli` not authenticated: notify user to run `acli auth` and stop
- Jira ticket not found or no access: report error and stop
- Ticket with no PRs or commits: note "No changes found for TICKET" in output
- PR merged and branch deleted: `gh pr diff` still works on merged PRs
- `gh` not authenticated: error and stop
- `acli` not available for Jira posting: generate file only, skip Jira upsert
