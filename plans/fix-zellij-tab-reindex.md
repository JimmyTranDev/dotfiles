# Fix Zellij Alt+u Tab Reindex

## TL;DR

- Alt+u tab reindex is broken because `Run` opens a new pane, and `go-to-tab` navigation conflicts with the transient pane lifecycle
- 2 files to change: the script and the keybinding
- Fix: use `rename-tab --tab-id` to avoid `go-to-tab` entirely, and use `in_place true` in the KDL keybinding to avoid spawning a visible pane
- Zellij 0.44.2 supports both `--tab-id` on `rename-tab` and `in_place` on `Run`
- Estimated effort: small (1-2 tasks)

## Overview

The `Alt+u` keybinding runs `zellij_update_tab_indexes.sh` via zellij's `Run` command, which spawns a temporary pane. The script uses `go-to-tab` + `rename-tab` to rename each tab, but navigating away from the tab containing the Run pane likely kills or disrupts the script. The fix is to use `rename-tab --tab-id <ID>` (no navigation needed) and `Run` with `in_place true` (no new pane visible).

## Architecture

- **Keybinding**: `src/zellij/config.kdl:133` — `Alt u` in `shared_among "normal" "locked"`
- **Script**: `etc/scripts/src/zellij_update_tab_indexes.sh` — parses layout, renames tabs
- **Related**: `etc/scripts/src/zellij_close_and_reindex.sh` — closes tab then calls the reindex script

## Tasks

### Task 1: Rewrite reindex script to use `rename-tab --tab-id`
- **File**: `etc/scripts/src/zellij_update_tab_indexes.sh`
- **Changes**:
  1. Extract tab IDs from `dump-layout` output (the `id=N` attribute on each `tab` line)
  2. Replace the `go-to-tab` + `rename-tab` loop with `zellij action rename-tab --tab-id <ID> <NEW_NAME>` for each tab
  3. Remove all `go-to-tab` calls and the final "navigate back" logic — they're no longer needed
  4. Remove `sleep 0.03` delays — no navigation means no race conditions
  5. Add debug logging to `/tmp/zellij_reindex.log` (write layout, tab names, rename actions) to aid future debugging
- **Complexity**: small
- **Parallel**: yes

### Task 2: Update keybinding to use `in_place true`
- **File**: `src/zellij/config.kdl`
- **Changes**:
  - Line 133: Add `in_place true` to the `Run` command so the script runs in the current pane without spawning a new visible pane
  - Line 128 (`Alt q`): Also add `in_place true` to the close-and-reindex binding for consistency
  - Line 53 (tab mode `x`): Same for the tab-mode close-and-reindex binding
- **Complexity**: small
- **Parallel**: yes (independent of Task 1)

## Edge Cases

- Tabs with no custom name (default "Tab #N") — skip (already handled)
- Tabs with names that are only numbers — skip (already handled)
- Single tab sessions — no-op cleanly
- Tab IDs may not be sequential — parse from layout, don't assume ordering

## Testing Approach

- Manual: open 3+ named tabs, close one in the middle, press Alt+u, verify sequential renumbering
- Check `/tmp/zellij_reindex.log` for execution trace
- Verify focus stays on current tab (no navigation should occur)

## Open Questions

### Requirements
- Decision: fixing this script also fixes `zellij_close_and_reindex.sh` since it calls the same script

### Architecture
- Decision: Zellij 0.44.2 confirmed. `rename-tab --tab-id` and `Run` with `in_place` are both supported.
