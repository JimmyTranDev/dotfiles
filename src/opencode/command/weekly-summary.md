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
   - Default (current repo): `~/Programming/JimmyTranDev/dotfiles/etc/scripts/src/ai/weekly-summary.sh --json`
   - Multi-repo: `~/Programming/JimmyTranDev/dotfiles/etc/scripts/src/ai/weekly-summary.sh --json --dir ~/Programming`
   - Custom date: add `--since YYYY-MM-DD` if provided in `$ARGUMENTS`

3. Parse the JSON output to get commits and ticket keys

4. For each unique Jira ticket key, fetch the ticket summary and status:
   - `acli jira workitem view --key "<KEY>" --json`
   - If `acli` is not available, skip Jira lookups and show commits only with a warning

5. Query Jira for tickets transitioned to QA/Testable this week:
   - `acli jira workitem search --jql "assignee = currentUser() AND status changed to 'Testable' after 'YYYY-MM-DD'"`
   - Extract any ticket keys not already found in commits — these are "moved to QA" without commits this week

6. Format the output as a grouped summary:

```
## Weekly Summary (since YYYY-MM-DD)

### By Ticket
#### [PROJ-123] Ticket summary — Status
- `abc1234` repo-name: commit message (YYYY-MM-DD)
- `def5678` repo-name: commit message (YYYY-MM-DD)

#### [PROJ-456] Ticket summary — Status
- `ghi9012` repo-name: commit message (YYYY-MM-DD)

### Moved to QA (no commits this week)
#### [PROJ-789] Ticket summary — Testable

### Unlinked Commits
- `jkl3456` repo-name: commit message (YYYY-MM-DD)

### Totals
- X tickets touched (Y with commits, Z moved to QA only)
- A commits
- B unlinked commits

### Standup Script
> I worked on [PROJ-123] — [brief description of what was done], it's currently [status].
> I also worked on [PROJ-456] — [brief description], now in [status].
> [One line per ticket, first-person, past tense for completed work, present tense for current status.]
> [If there are unlinked commits, add: "I also did some work outside of tickets — [brief summary]."]
```

7. Generate the standup script:
   - Include every ticket from the summary (both "By Ticket" and "Moved to QA" sections)
   - Write one sentence per ticket in first-person: "I worked on [ticket] — [what was done], it's currently [status]."
   - If there are unlinked commits, add a final sentence summarizing them
   - Keep each line short enough to read aloud in ~10 seconds
   - If there are no tickets (only unlinked commits), summarize the commits directly

8. Output the formatted summary to chat

## Edge Cases

- No commits this week: report "No activity since <date>"
- Commit messages without Jira keys: list under "Unlinked Commits"
- `acli` not available or not authenticated: skip Jira lookups, show commits only with warning
- `--dir` flag scans all git repos under the directory (max depth 3)
