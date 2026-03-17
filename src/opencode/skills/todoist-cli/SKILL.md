---
name: todoist-cli
description: Todoist CLI (td) command reference for task management, projects, labels, filters, comments, and JSON output for automation
---

## Overview

The `td` command is the Todoist CLI. Install via `npm install -g @doist/todoist-cli`.

- Use `td task add` (not `td add`) for structured task creation with flags
- Use `--json` or `--ndjson` for machine-readable output
- Use `--full` with JSON to include all fields
- Reference entities by name, `id:xxx`, or Todoist web URL

## Authentication

```bash
td auth login           # OAuth browser flow
td auth token "TOKEN"   # manual token
td auth status          # check auth
td auth logout          # remove token
```

`TODOIST_API_TOKEN` env var overrides stored token.

## Quick Add vs Structured Add

| Command | Use Case | Example |
|---------|----------|---------|
| `td add "text"` | Natural language (human shorthand) | `td add "Buy milk tomorrow p1 #Shopping"` |
| `td task add` | Structured flags (agents/scripts) | `td task add "Buy milk" --due tomorrow --priority p1 --project Shopping` |

## Task Commands

### td task add

```bash
td task add "content" [options]
```

| Flag | Description |
|------|-------------|
| `--due <date>` | Due date (natural language or YYYY-MM-DD) |
| `--deadline <date>` | Deadline date (YYYY-MM-DD) |
| `--priority <p1-p4>` | Priority level |
| `--project <name>` | Project name or id:xxx |
| `--section <ref>` | Section (name with --project, or id:xxx) |
| `--labels <a,b>` | Comma-separated labels |
| `--parent <ref>` | Parent task reference |
| `--description <text>` | Task description |
| `--assignee <ref>` | User (name, email, id:xxx, or "me") |
| `--duration <time>` | Duration (30m, 1h, 2h15m) |
| `--order <n>` | Position order |
| `--uncompletable` | Mark task as uncompletable |
| `--stdin` | Read content from stdin |

### td task list

```bash
td task list [options]
```

| Flag | Description |
|------|-------------|
| `--project <name>` | Filter by project name or id:xxx |
| `--parent <ref>` | Filter subtasks of parent |
| `--label <name>` | Filter by label (comma-separated) |
| `--priority <p1-p4>` | Filter by priority |
| `--due <date>` | Filter by due date (today, overdue, YYYY-MM-DD) |
| `--filter <query>` | Raw Todoist filter query |
| `--assignee <ref>` | Filter by assignee (me or id:xxx) |
| `--unassigned` | Only unassigned tasks |
| `--workspace <name>` | Filter to workspace |
| `--personal` | Filter to personal projects |
| `--limit <n>` | Limit results (default: 300) |
| `--all` | Fetch all results |
| `--json` | JSON output |
| `--ndjson` | Newline-delimited JSON |
| `--full` | All fields in JSON |
| `--show-urls` | Show web app URLs |

### td task view / complete / delete / uncomplete

```bash
td task view [ref]          # view details (--json, --full, --raw)
td task complete [ref]      # complete task
td task uncomplete [ref]    # reopen (requires id:xxx)
td task delete [ref]        # delete task
td task browse [ref]        # open in browser
```

### td task update

```bash
td task update [ref] [options]
```

| Flag | Description |
|------|-------------|
| `--content <text>` | New content |
| `--due <date>` | New due date |
| `--deadline <date>` | Deadline (YYYY-MM-DD) |
| `--no-deadline` | Remove deadline |
| `--priority <p1-p4>` | New priority |
| `--labels <a,b>` | Replace labels |
| `--description <text>` | New description |
| `--assignee <ref>` | Assign user |
| `--unassign` | Remove assignee |
| `--duration <time>` | Duration |
| `--completable` | Mark completable |
| `--uncompletable` | Mark uncompletable |
| `--stdin` | Read content from stdin |

### td task move

```bash
td task move [ref] --project <ref> [--section <ref>] [--parent <ref>]
td task move [ref] --no-parent    # move to project root
td task move [ref] --no-section   # remove from section
```

## View Commands

```bash
td today [--json] [--ndjson] [--full] [--any-assignee] [--workspace <name>] [--personal]
td upcoming [days] [--json] [--ndjson] [--full] [--any-assignee]
td inbox [--json] [--ndjson] [--full]
td completed [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--project <name>] [--json]
```

## Project Commands

```bash
td project list [--json] [--personal] [--all] [--show-urls]
td project view [ref] [--json] [--full]
td project create --name "Name" [--color <color>] [--favorite] [--parent <ref>] [--view-style list|board|calendar]
td project update [ref] [options]
td project delete [ref]
td project archive [ref]
td project unarchive [ref]
td project collaborators [ref]
td project move [ref] [options]
td project browse [ref]
```

## Label Commands

```bash
td label list [--json] [--all]
td label view [ref] [--json]
td label create [options]
td label update [ref] [options]
td label delete [name]
td label browse [ref]
```

## Comment Commands

```bash
td comment list [ref] [--json]           # comments on task
td comment list [ref] -P [--json]        # comments on project
td comment add [ref] --content "text"    # add to task
td comment add [ref] -P --content "text" # add to project
td comment add [ref] --file <path>       # attach file
td comment add [ref] --stdin             # read content from stdin
td comment update [id] --content "text"
td comment delete [id]
td comment view [id]
td comment browse [id]
```

## Section Commands

```bash
td section list [project] [--json]
td section create --name "Name" --project <ref>
td section update [id] --name "New Name"
td section delete [id]
td section browse [id]
```

## Filter Commands

```bash
td filter list [--json]
td filter create --name "Name" --query "filter query"
td filter view [ref] [--json]       # show matching tasks
td filter update [ref] [options]
td filter delete [ref]
td filter browse [ref]
```

## Other Commands

```bash
td activity [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--type task|comment|project] [--event added|completed|...] [--json] [--markdown]
td stats [--json]
td stats goals
td stats vacation
td notification list [--json]
td notification view [id]
td notification accept [id]
td notification reject [id]
td notification read [id]
td workspace list [--json]
td workspace view [ref]
td workspace projects [ref]
td workspace users [ref]
td reminder list [task]
td reminder add [task] [options]
td reminder update [id] [options]
td reminder delete [id]
td settings view [--json]
td settings update [options]
td settings themes
td view <url> [args...]             # route Todoist web URL to CLI command
td update                           # self-update CLI
td completion install [bash|zsh|fish]
td completion uninstall
```

## Entity References

Tasks, projects, labels, and filters accept multiple reference formats:

| Format | Example |
|--------|---------|
| Name search | `td task view "Buy milk"` |
| ID prefix | `td task view id:8204963997` |
| Todoist URL | `td task view https://app.todoist.com/app/task/buy-milk-8Jx4mVr72kPn3QwB` |

## Output Formats

| Flag | Format | Use Case |
|------|--------|----------|
| (none) | Human-readable table | Terminal display |
| `--json` | JSON array | Scripting, piping |
| `--ndjson` | Newline-delimited JSON | Streaming, large results |
| `--full` | All fields in JSON | Detailed inspection |
| `--raw` | No markdown rendering | Plain text |
| `--show-urls` | Add web URLs | Copy-paste links |

## Global Flags

| Flag | Description |
|------|-------------|
| `--no-spinner` | Disable loading animations |
| `--progress-jsonl [path]` | JSONL progress events to stderr/file |
| `-v` to `-vvvv` | Verbosity (API latency debugging) |
| `--accessible` | Text labels for color-coded output (or `TD_ACCESSIBLE=1`) |

## Common Workflows

```bash
# list today's tasks as JSON
td today --json

# add task with due date to specific project
td task add "Review PR" --due tomorrow --project "Work" --priority p2

# complete a task by name
td task complete "Buy milk"

# move task to different project and section
td task move "Design review" --project "Work" --section "In Progress"

# list tasks with a specific filter query
td task list --filter "priority 1 & today"

# view activity for today
td activity --since $(date +%Y-%m-%d) --json

# add comment with stdin content
echo "Detailed notes here" | td comment add "Task name" --stdin
```
