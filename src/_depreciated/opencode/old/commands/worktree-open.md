---
name: worktree-open
description: Open multiple worktrees in separate Zellij tabs
---

Usage: /worktree-open [branch names or PR numbers]

$ARGUMENTS

Load the **tool-zellij** skill for Zellij tab operations.

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

- If a worktree path doesn't exist, offer to recover it via `/pr-recover`
- If Zellij is not running, fall back to reporting the paths for manual navigation
- If no worktrees exist, notify the user
