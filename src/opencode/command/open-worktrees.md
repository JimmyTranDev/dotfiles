---
name: open-worktrees
description: Open multiple worktrees in separate Zellij tabs
---

Usage: /open-worktrees [branch names or PR numbers]

$ARGUMENTS

Open one or more worktrees in separate Zellij tabs for parallel work.

## Workflow

1. Determine which worktrees to open:
   - If `$ARGUMENTS` lists branch names or PR numbers, use those
   - If no arguments, list all active worktrees via `git worktree list` and let the user multi-select

2. For each selected worktree:
   - Verify the worktree path exists at `~/Programming/wcreated/<branch-name>`
   - Open a new Zellij tab with the worktree directory:
     ```bash
     zellij action new-tab --layout default --cwd ~/Programming/wcreated/<branch-name> --name <branch-name>
     ```

3. Report: "Opened N tabs: [branch-list]"

## Edge Cases

- If a worktree path doesn't exist, offer to recover it via `/recover-pr`
- If Zellij is not running, fall back to reporting the paths for manual navigation
- If no worktrees exist, notify the user
