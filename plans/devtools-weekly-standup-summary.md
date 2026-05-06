---
todoist: https://app.todoist.com/app/task/add-a-combined-commit-check-this-week-and-jira-check-command-create-a-script-for-it-6gXMvxHpqVr4QWQM
---

# Create Weekly Standup Summary Command and Script

## Overview

Create a new `/weekly-summary` command and a backing shell script that combines this week's git commits with Jira ticket statuses to generate a standup/reporting summary. The script does the data gathering; the command formats and presents it.

## Architecture

- New script: `etc/scripts/ai/weekly-summary.sh` (data gathering, machine-readable output)
- New command: `src/opencode/command/weekly-summary.md` (formatting and presentation)
- Uses `git log` for commits and `acli` for Jira ticket lookup

## Data flow

1. Script runs `git log --since="last monday" --author="$(git config user.name)"` across all repos or current repo
2. Extract Jira ticket keys from commit messages (regex: `[A-Z]+-[0-9]+`)
3. For each unique ticket, fetch summary and status via `acli jira view <key> --output-format json`
4. Output structured JSON: `{ commits: [...], tickets: [...] }`
5. Command receives JSON, formats into readable summary grouped by ticket

## Tasks

1. **Create `etc/scripts/ai/weekly-summary.sh`** (medium)
   - Follow existing script conventions: `set -e`, source `common/logging.sh`
   - Accept flags: `--since <date>` (default: last Monday), `--dir <path>` (default: `~/Programming`), `--json` (machine output)
   - Walk all git repos under the directory
   - Gather commits with author, date, message, ticket key
   - Fetch Jira ticket info for each unique key
   - Output JSON to stdout when `--json`, human-readable table otherwise
   - Complexity: medium
   - Parallel: yes (independent of task 2)

2. **Create `src/opencode/command/weekly-summary.md`** (medium)
   - Frontmatter: name `weekly-summary`, description
   - Run the script with `--json`
   - Format output as grouped summary:
     - By ticket: ticket key, summary, status, list of commits
     - Orphan commits (no ticket key) listed separately
   - Show total: X tickets touched, Y commits, Z orphan commits
   - Complexity: medium
   - Parallel: yes (independent of task 1 for writing, but runtime depends on script)

## State changes

None. Read-only queries.

## Edge cases

- No commits this week: report "no activity"
- Commit messages without Jira keys: list as "unlinked commits"
- `acli` not available or not authenticated: skip Jira lookups, show commits only with warning
- Multiple repos: initially support current repo only, flag for future multi-repo

## Testing approach

- Manual: run script directly, verify JSON output
- Manual: run `/weekly-summary` in OpenCode, verify formatted output
- Script can be tested with `--since` flag pointing to a known date range

## Open questions

- **Decision:** Scan all repos under `~/Programming/`, not just the current repo.
- **Decision:** No Jira worklogs — just show ticket status and commits.
