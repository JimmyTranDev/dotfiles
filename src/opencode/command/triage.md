---
name: triage
description: Walk through review findings one by one, decide actions for all, then execute
---

Usage: /triage

$ARGUMENTS

## Phase 1: Collect Decisions

Parse the review output from the current conversation. Extract each finding (critical, important, and suggestion) into an ordered list, ranked by severity (critical first, then important, then suggestions).

For each finding, present it to the user using the question tool with these options:
- **Fix** — mark for fixing
- **TODO** — mark for tracking as a TODO
- **Skip** — ignore this finding
- **Stop** — skip all remaining findings and proceed to execution

## Phase 2: Confirm Plan

After all decisions are collected (or the user stops), present a summary of the plan:

```
## Triage Plan
- 🔧 X findings to fix
- 📋 Y findings to track as TODOs
- ⏭️ Z findings skipped

### Will Fix:
1. [file:line] — [description]
2. [file:line] — [description]

### Will Track as TODO:
1. [file:line] — [description]
```

Ask the user to confirm: **Execute plan**, **Revise** (go back and change decisions), or **Cancel**.

## Phase 3: Execute

After confirmation, execute all decisions:

1. **Fixes**: Launch the **fixer** agent for each finding marked "Fix". Run independent fixes in parallel where they affect different files. Show what changed after each fix.
2. **TODOs**: For each finding marked "TODO", ask the user where to track it (inline comment, issue tracker, etc.) and create the tracking item.

## Summary

After execution, present final results:
- X findings fixed
- Y findings tracked as TODOs
- Z findings skipped

Do NOT auto-stage or commit — the user decides when to commit after triage is complete.
