---
name: acli
description: Manages Jira from the terminal via the Atlassian CLI `acli`. Use when reading, searching, creating, editing, assigning, commenting on, or transitioning Jira work items/tickets/issues, running JQL, or working a Jira ticket key (e.g. ABC-123) or an atlassian.net browse URL. Triggers on "acli", "jira", "atlassian cli", "work item", "transition the ticket", "JQL".
---

# Atlassian CLI (acli) — Jira

## Overview

`acli` is the official Atlassian CLI — the canonical way to read and mutate
Jira from the terminal. Route every Jira interaction through `acli` (not
WebFetch or a browser) so behavior stays scriptable and JSON-parseable. A Jira
work item is referenced by its **key** (e.g. `ABC-123`); the same id appears at
the end of a browse URL (`https://<site>.atlassian.net/browse/ABC-123`).

Install: `brew install acli` (already installed at `/opt/homebrew/bin/acli`).
Verify with `acli --version`.

> Atlassian renamed Jira "issues" to **work items**. The command group is
> `acli jira workitem`. Use `--json` on any read command for machine-parseable
> output.

## When to Use

- Any time a Jira key (`ABC-123`) or `*.atlassian.net/browse/...` URL appears —
  read it with `acli jira workitem view`, never WebFetch.
- Reading a ticket's description / acceptance criteria to seed implementation.
- Searching with JQL, creating, editing, assigning, commenting, or transitioning
  work items.
- Posting progress back to a ticket and moving it across its workflow.

**When NOT to use:**

- Do **not** WebFetch or screen-scrape `*.atlassian.net` URLs — they return a
  JS shell with no ticket data. Always use `acli`.
- Confluence/admin tasks use `acli confluence` / `acli admin` (out of scope for
  this skill, which focuses on Jira work items).

## Authentication

```bash
acli auth login      # OAuth browser flow (global, all products)
acli auth status     # show the active account
acli auth switch     # switch between authenticated accounts
acli auth logout     # log out of all accounts
```

If a command returns an auth error, run `acli auth status` first and re-`login`
if needed. **Never** print tokens or auth output containing secrets.

## Core Commands (`acli jira workitem`)

### View a work item

```bash
acli jira workitem view ABC-123                       # default fields
acli jira workitem view ABC-123 --json                # machine-parseable
acli jira workitem view ABC-123 --fields summary,description,status,comment
acli jira workitem view ABC-123 --web                 # open in browser
```

Default fields: `key,issuetype,summary,status,assignee,description`. Use
`--fields '*all'` for everything, or prefix a field with `-` to exclude it
(e.g. `--fields '*navigable,-comment'`).

### Search with JQL

```bash
acli jira workitem search --jql "project = ABC AND status = 'In Progress'" --json
acli jira workitem search --jql "assignee = currentUser() AND statusCategory != Done" --limit 50 --json
acli jira workitem search --jql "project = ABC" --paginate --csv
acli jira workitem search --jql "project = ABC" --count          # just the count
acli jira workitem search --filter 10001 --web                   # saved filter by id
```

| Flag | Description |
|------|-------------|
| `-j, --jql <query>` | JQL query |
| `--filter <id>` | Saved filter id |
| `-f, --fields <list>` | Comma-separated fields (default `issuetype,key,assignee,priority,status,summary`) |
| `-l, --limit <n>` | Max work items to fetch |
| `--paginate` | Fetch all pages |
| `--count` | Return only the match count |
| `--json` / `--csv` | Output format |
| `-w, --web` | Open the search in a browser |

### Create

```bash
acli jira workitem create --project ABC --type Task --summary "New task" --json
acli jira workitem create --project ABC --type Bug --summary "Crash on save" \
  --description "Steps to reproduce..." --assignee "@me" --label "cli,bug"
acli jira workitem create --project ABC --type Story --summary "..." --parent ABC-100
```

| Flag | Description |
|------|-------------|
| `-p, --project <key>` | Project key (required) |
| `-t, --type <type>` | Work item type: `Epic`, `Story`, `Task`, `Bug`, ... (required) |
| `-s, --summary <text>` | Summary |
| `-d, --description <text>` | Description (plain text or ADF) |
| `--description-file <path>` | Read description from a file |
| `-a, --assignee <ref>` | Email, account id, `@me`, or `default` |
| `-l, --label <a,b>` | Labels (comma-separated) |
| `--parent <key>` | Parent work item |
| `-e, --editor` | Open `$EDITOR` for summary/description |
| `--from-json <path>` | Create from a JSON definition (`--generate-json` scaffolds one) |
| `--json` | JSON output |

### Edit

```bash
acli jira workitem edit --key ABC-123 --summary "Updated summary" --yes
acli jira workitem edit --key ABC-123 --assignee "user@example.com" --yes
acli jira workitem edit --key ABC-123 --labels "ready,backend" --yes
acli jira workitem edit --key "ABC-1,ABC-2" --description-file notes.md --yes
```

`-y, --yes` skips the confirmation prompt. Multiple keys are comma-separated.
Supports `--remove-assignee` and `--remove-labels <list>`.

### Assign

```bash
acli jira workitem assign --key ABC-123 --assignee "@me" --yes
acli jira workitem assign --key ABC-123 --assignee "user@example.com" --yes
acli jira workitem assign --key ABC-123 --remove-assignee --yes
```

`@me` self-assigns; `default` assigns the project default.

### Transition (change status)

```bash
acli jira workitem transition --key ABC-123 --status "In Progress" --yes
acli jira workitem transition --key ABC-123 --status "Done" --yes
acli jira workitem transition --jql "project = ABC AND status = 'To Do'" --status "In Progress" --yes
```

Status **names are workflow-specific** (e.g. `In Progress`, `In Review`,
`Done`). If a status name is rejected, `view` the ticket to read its current
status and confirm the exact target name from the project's workflow before
retrying. `-y, --yes` confirms without prompting.

### Comment

```bash
acli jira workitem comment create --key ABC-123 --body "Implemented behind a flag; PR #42."
acli jira workitem comment create --key ABC-123 --body-file summary.md --json
acli jira workitem comment create --key ABC-123 --edit-last --body "Updated note"
acli jira workitem comment list --key ABC-123 --json
```

`comment` subcommands: `create`, `list`, `update`, `delete`, `visibility`.

### Other work item subcommands

`archive`, `unarchive`, `clone`, `delete`, `link`, `watcher`, `list-watchers`,
`attachment`, `create-bulk`. Run `acli jira workitem <sub> --help` for flags.

## Other Jira groups

```bash
acli jira board --help        # boards
acli jira sprint --help       # sprints (list/create/start/close, add items)
acli jira project --help      # projects
acli jira filter --help       # saved filters
acli jira field --help        # fields
acli jira dashboard --help    # dashboards
```

## Conventions

- Always pass `--json` for any output you intend to parse; pipe to `jq`.
- Reference work items by key (`ABC-123`) — extract it from a browse URL's last
  path segment when given a URL.
- Mutating commands (`create`, `edit`, `assign`, `transition`, `delete`,
  `comment`) accept `-y/--yes` to skip prompts; in autonomous flows pass `--yes`
  but confirm destructive actions (`delete`, `archive`) with the user first.
- Discover exact flags with `acli <group> <command> --help` rather than
  guessing — the surface evolves between versions.

## Common Workflows

```bash
# Read a ticket as JSON (seed an implementation from its description)
acli jira workitem view ABC-123 --fields summary,description,status --json | jq

# Pick up a ticket: self-assign and move to In Progress
acli jira workitem assign --key ABC-123 --assignee "@me" --yes
acli jira workitem transition --key ABC-123 --status "In Progress" --yes

# My open work
acli jira workitem search --jql "assignee = currentUser() AND statusCategory != Done" --json

# Report progress and hand off for review
acli jira workitem comment create --key ABC-123 --body "Done on branch feature/ABC-123; PR opened."
acli jira workitem transition --key ABC-123 --status "In Review" --yes
```
