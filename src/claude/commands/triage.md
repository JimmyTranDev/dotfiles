---
description: Walk through review findings one by one, decide actions for all, then execute
argument-hint: $ARGUMENTS
---

Usage: /triage

$ARGUMENTS

## Phase 1: Collect Decisions

Load skills in parallel: **code-follower** (to understand codebase conventions when suggesting fixes), **comm-natural-speech** (for presenting options conversationally).

Parse the review output from the current conversation. Extract each finding (critical, important, and suggestion) into an ordered list, ranked by severity (critical first, then important, then suggestions).

For each finding, present it to the user with full context:
- The severity level (🔴 critical / 🟡 important / 💡 suggestion)
- The file and line location
- The full issue description and why it matters
- The suggested fix
- The relevant code snippet (read the file at the specified line to show surrounding context)

Then use the question tool with contextual solution options tailored to the specific finding. Generate 3-5 concrete options based on the issue type. Examples:

For a dead code finding:
- "Remove the unused function entirely"
- "Add a @deprecated annotation and track for removal"
- "Skip — keeping for backward compatibility"

For a logic/edge case finding:
- "Add a null check with early return"
- "Add validation at the caller instead"
- "Add a unit test to document the expected behavior"
- "Skip — already handled upstream"

For a naming/clarity finding:
- "Rename to [suggested name]"
- "Extract to a well-named helper function"
- "Skip — clear enough in context"

For a performance finding:
- "Memoize the computation"
- "Move to a batch query"
- "Skip — acceptable for current scale"

Always include as the last two options:
- **Skip** — accept the current code as-is
- **Stop** — skip all remaining findings and proceed to execution

Mark each non-skip/stop option as either a "Fix" (will change code) or "TODO" (will track for later) in the plan.

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
