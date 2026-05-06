---
todoist: https://app.todoist.com/app/task/remove-the-auto-learn-meta-skill-other-than-the-learn-command-6gXMwR963VQWPcwM
---

# Remove Auto-Learn Triggers from AGENTS.md

## Overview

Remove the automatic meta-skill-learnings and meta-auto-improve triggers from `AGENTS.md` so these behaviors only activate when the user explicitly runs `/learn`. Currently, every task triggers skill improvement evaluation, which adds latency and unwanted file changes.

## Architecture

Two files to edit: `src/opencode/AGENTS.md` and `AGENTS.md` (root). The `/learn` command in `src/opencode/command/learn.md` stays unchanged.

## Tasks

1. **Edit `src/opencode/AGENTS.md`** (small)
   - Remove the bullet: "Improve skills from discoveries" (the one referencing meta-skill-learnings)
   - Remove the bullet: "Auto-improve skills and commands" (the one referencing meta-auto-improve)
   - Keep all other Universal Rules intact
   - Complexity: small
   - Sequential: no dependencies

2. **Edit `AGENTS.md` (root)** (small)
   - Check for any duplicate references to auto-learn/auto-improve and remove them
   - Complexity: small
   - Parallel: yes

3. **Verify `/learn` command is unaffected** (small)
   - Read `src/opencode/command/learn.md` and confirm it independently loads the skills it needs
   - No changes needed (already loads meta-skill-learnings and meta-opencode-authoring directly)
   - Complexity: small
   - Parallel: yes

## Edge cases

- Other commands may reference "load meta-auto-improve" inline; those are fine since they're explicit invocations, not automatic triggers
- The skills themselves (`meta-auto-improve/SKILL.md`, `meta-skill-learnings/SKILL.md`) remain available for manual loading

## Testing approach

- Verify: after editing, grep AGENTS.md files for "auto-improve" and "meta-skill-learnings" to confirm removal
- Verify: `/learn` command still references the skills it needs independently

## Open questions

None. This task is straightforward.
