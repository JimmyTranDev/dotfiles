---
name: tool-acli
description: Atlassian CLI (acli) command reference for Jira work items, comments, transitions, search, and Confluence operations
---

## Overview

The `acli` command is the Atlassian CLI (installed via Homebrew: `brew install atlassian-labs/tap/acli`).

- Top-level commands: `jira`, `confluence`, `admin`, `auth`, `config`
- Jira subcommands: `workitem`, `board`, `dashboard`, `field`, `filter`, `project`, `sprint`
- Use `--json` flag for machine-readable output where supported

## Authentication

```bash
acli auth              # interactive auth flow
acli jira auth         # authenticate for Jira specifically
```

## Jira Work Items

```bash
acli jira workitem view --key "BW-1234"              # view a work item
acli jira workitem search --jql "project = BW"       # search with JQL
acli jira workitem create --project "BW" --type "Task" --summary "Title"
acli jira workitem edit --key "BW-1234" --summary "New title"
acli jira workitem transition --key "BW-1234"        # transition status
acli jira workitem assign --key "BW-1234"            # assign work item
acli jira workitem delete --key "BW-1234"            # delete work item
```

## Comments

```bash
acli jira workitem comment create --key "BW-1234" --body "Comment text"
acli jira workitem comment create --key "BW-1234" --body-file "comment.txt"
acli jira workitem comment create --jql "project = BW" --body "Bulk comment"
acli jira workitem comment create --key "BW-1234" --editor   # open text editor
acli jira workitem comment list --key "BW-1234"
acli jira workitem comment update --key "BW-1234"
acli jira workitem comment delete --key "BW-1234"
```

### Comment Flags

| Flag | Description |
|------|-------------|
| `-b, --body` | Comment body (plain text or ADF) |
| `-F, --body-file` | Path to file with comment body |
| `-e, --edit-last` | Edit the last comment from same author |
| `--editor` | Open text editor for body |
| `--jql` | Apply to multiple work items via JQL |
| `--filter` | Filter ID of work items |
| `-k, --key` | Work item key(s) |
| `--ignore-errors` | Continue on errors |
| `--json` | JSON output |

## Attachments

```bash
acli jira workitem attachment           # manage attachments
```

## Search

```bash
acli jira workitem search --jql "assignee = currentUser() AND status != Done"
acli jira workitem search --jql "project = BW AND sprint in openSprints()"
```

## Boards and Sprints

```bash
acli jira board list
acli jira sprint list --board "Board Name"
```

## Gotchas and Tips

- The `--key` flag accepts a single key or comma-separated keys for bulk operations
- Use `--ignore-errors` when operating on multiple items to skip failures
- Comment body supports plain text — no markdown rendering in Jira comments (use ADF for rich formatting)
- Escape double quotes in `--body` strings with backslash
- For multiline comments, prefer `--body-file` with a temp file or `--editor`
