---
name: triage
description: Walk through review findings one by one and decide what action to take for each
---

Usage: /triage

$ARGUMENTS

Parse the review output from the current conversation. Extract each finding (critical, important, and suggestion) into an ordered list, ranked by severity (critical first, then important, then suggestions).

For each finding, present it to the user using the question tool with these options:
- **Fix now** — launch the **fixer** agent to address this finding immediately
- **Create TODO** — add a TODO comment or track it for later (ask where to track if unclear)
- **Skip** — acknowledge and move on without action
- **Stop** — end the triage, skip all remaining findings

After each "Fix now" selection:
1. Launch the **fixer** agent with the finding's location, description, and suggested fix
2. After the fix is applied, show the user what changed
3. Continue to the next finding

After all findings are processed (or the user stops), present a summary:
- X findings fixed
- Y findings deferred as TODOs
- Z findings skipped

Do NOT auto-stage or commit — the user decides when to commit after triage is complete.
