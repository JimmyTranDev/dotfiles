---
name: weekly-summary
description: Generate a weekly standup summary combining git commits and Jira ticket statuses
---

Usage: /weekly-summary [--dir <path>] [--since <date>]

$ARGUMENTS

Generate a weekly summary of git activity and associated Jira tickets for standup reporting.

## Workflow

1. Load the **tool-acli** skill

2. Run the weekly-summary script with JSON output:
   - Default (current repo): `~/Programming/JimmyTranDev/dotfiles/etc/scripts/ai/weekly-summary.sh --json`
   - Multi-repo: `~/Programming/JimmyTranDev/dotfiles/etc/scripts/ai/weekly-summary.sh --json --dir ~/Programming`
   - Custom date: add `--since YYYY-MM-DD` if provided in `$ARGUMENTS`

3. Parse the JSON output to get commits and ticket keys

4. For each unique Jira ticket key, fetch the ticket summary and status:
   - `acli jira workitem view --key "<KEY>" --json`
   - If `acli` is not available, skip Jira lookups and show commits only with a warning

5. Format the output as a grouped summary:

```
## Weekly Summary (since YYYY-MM-DD)

### By Ticket
#### [PROJ-123] Ticket summary — Status
- `abc1234` repo-name: commit message (YYYY-MM-DD)
- `def5678` repo-name: commit message (YYYY-MM-DD)

#### [PROJ-456] Ticket summary — Status
- `ghi9012` repo-name: commit message (YYYY-MM-DD)

### Unlinked Commits
- `jkl3456` repo-name: commit message (YYYY-MM-DD)

### Totals
- X tickets touched
- Y commits
- Z unlinked commits
```

6. Output the formatted summary to chat

## Edge Cases

- No commits this week: report "No activity since <date>"
- Commit messages without Jira keys: list under "Unlinked Commits"
- `acli` not available or not authenticated: skip Jira lookups, show commits only with warning
- `--dir` flag scans all git repos under the directory (max depth 3)
