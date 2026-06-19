---
name: clarify-todoist
description: Walk through Todoist tasks one by one with explain, downgrade-priority, delete, or skip options
---

Usage: /clarify-todoist <section-or-project-url> [p1|p2|p3|p4]

Walk through the tasks in a Todoist section or project one at a time. For each task, choose to **explain** it, **downgrade** its priority, **delete** it, or **skip** it. Deletion is destructive and always requires explicit confirmation.

$ARGUMENTS

## Composition (audit)

- Reuses the **tool-todoist-cli** skill (the `td` CLI) and the per-item question-tool loop established by `/triage-comments`.
- vs **/triage-todoist-section**: that collects *all* decisions then batch-executes a consolidation (keep/rewrite/merge/move/reparent). `/clarify-todoist` is a focused per-task loop with a fixed option set `{explain, downgrade, delete, skip}`, acting on each task before moving on.
- vs **/clarify**: unrelated — that disambiguates a code or spec request; this only shares the verb.

## Setup

1. Load the **tool-todoist-cli** skill.

2. Export the API token before any `td` call:
   `export TODOIST_API_TOKEN="$PRI_TODOIST_API_TOKEN"`

3. Parse `$ARGUMENTS`:
   - A Todoist section URL (`/app/section/...`), project URL (`/app/project/...`), or project name
   - An optional priority token (`p1`-`p4`) to restrict the walk to a single priority level
   - If no URL or project is given, ask the user which section or project to clarify

4. Fetch tasks (mind the section-URL limitation — `td view` rejects section URLs):
   - **Section URL**: run `~/Programming/JimmyTranDev/dotfiles/etc/scripts/src/ai/triage-todoist.sh "<section-url>" [--priority <p1|p2|p3|p4>]`. It returns `{ section_id, total, tasks: [{ id, content, priority, labels, due_date, description, url }] }`. The `priority` field is the inverted API value (`4`=p1 … `1`=p4 — see **tool-todoist-cli**).
   - **Project URL or name**: `td task list --project "<name>" --json --full --show-urls` (add `--priority pN` when a priority token is present)
   - Present the fetched tasks with indices for reference

## Per-Task Loop

For each task, show: content, current priority (as the UI label `p(5 - priority)`), due date, labels, description, and URL. Then present options with the question tool:

- **Explain** — describe what the task likely means, why it might exist, and how to interpret it. Make no changes.
- **Downgrade priority** — lower it one UI level (p1→p2→p3→p4) via `td task update "<url>" --priority <next>`. The `--priority` flag takes UI labels; compute `next` as one step lower than the current label `p(5 - priority)`. If the task is already p4, there is nothing to downgrade — say so and treat it as skip.
- **Delete** — destructive; requires the confirmation gate below.
- **Skip** — move to the next task without changes.

The user may also type a custom instruction for any task.

## Delete Confirmation Gate

Deletion never happens on a single choice:

1. When **Delete** is chosen, show the task content and ask again with the question tool: **Confirm delete** or **Cancel**.
2. Only after **Confirm delete**, run `td task delete "<url>" --yes`.
3. On **Cancel**, leave the task untouched and move to the next.

## Summary

After the walk, report counts: explained, downgraded, deleted, skipped — and list any tasks that remain.

## Rules

- Never delete a task without passing the explicit confirmation gate.
- Downgrade only lowers priority by one level — it never raises it.
- Prefer explain/downgrade over delete; deletion is irreversible and loses history.
