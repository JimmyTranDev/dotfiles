---
description: Clarify and consolidate Todoist tasks in a section by collecting all decisions then executing in batch
argument-hint: $ARGUMENTS
---

Usage: /triage-todoist-section $ARGUMENTS

Walk through all tasks in a Todoist section, collect decisions about each task, then execute all changes in batch.

$ARGUMENTS should be a Todoist section URL, section name (with project), or project URL with section specified.

## Setup

1. Load the **tool-todoist-cli** skill.

2. Identify the section:
   - If `$ARGUMENTS` is a section URL, use it directly
   - If `$ARGUMENTS` is a section name, ask for the project name if not provided, then construct the URL
   - If no arguments, ask the user which project and section to triage

3. Fetch tasks using the `triage-todoist.sh` script:
   - Run: `~/Programming/JimmyTranDev/dotfiles/etc/scripts/src/ai/triage-todoist.sh "<section-url>" [--priority <p1|p2|p3|p4>]`
   - If a priority token (`p1`-`p4`) appears in `$ARGUMENTS`, pass it via `--priority`
   - The script outputs JSON with `{ section_id, total, tasks: [{ id, content, priority, labels, due_date, description, url }] }`
   - Present the task list to the user with indices for reference

## Phase 1: Collect Decisions

For each task (or group of related/duplicate tasks), ask the user:
- What does this task actually mean? Is it still relevant?
- Should duplicates be merged? Which title/description to keep?
- Should any tasks be broken down or combined?

Use the question tool with concrete options where possible. Common options:
- **Keep as-is** — no changes
- **Rewrite** — update title/description to be clearer
- **Merge with [other task]** — combine duplicates
- **Complete/remove** — task is done or no longer relevant
- **Reparent** — make subtask of another task
- **Move** — move to different section or project
- **Change priority** — update priority level
- **Skip** — move to next task
- **Stop** — skip remaining tasks, proceed to Phase 2

Do NOT execute any changes during this phase.

## Phase 2: Confirm Plan

After all decisions are collected (or the user stops), present a summary:

```
## Consolidation Plan
- X tasks to keep as-is
- Y tasks to rewrite
- Z tasks to complete/remove
- W tasks to merge
- V tasks to move/reparent

### Changes:
1. [task name] — [action description]
2. [task name] — [action description]
```

Ask the user to confirm: **Execute plan**, **Revise** (go back and change decisions), or **Cancel**.

## Phase 3: Execute

After confirmation, execute all changes using the appropriate `td` commands:
- `td task complete <ref>` for duplicates/irrelevant tasks
- `td task update <ref> --content "new title"` for rewrites
- `td task update <ref> --description "new desc"` for added context
- `td task move <ref> --parent <ref>` for reparenting
- `td task delete <ref>` only if user explicitly requests deletion
- `td task update <ref> --priority <p>` for priority changes

## Phase 4: Summary

Present the final state:
- List the remaining tasks in the section after consolidation
- Show a before/after count
- Summary of all changes made

Do not delete tasks unless the user explicitly asks — prefer completing them to preserve history.
Do not move tasks out of the section unless the user requests it.
