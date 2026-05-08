---
todoist: https://app.todoist.com/app/section/dotfiles-6f29Fcgcv4993gQG
---

# OpenCode Command Improvements

## TL;DR

- 3 command improvements: weekly-summary standup section, specify deeper questioning, fix-conflict auto-continue
- All changes are to markdown command files in `src/opencode/command/`
- Estimated effort: small (each task is a targeted edit to an existing file)
- No new files needed, no scripts to create

## Overview

Three p1 Todoist tasks requesting improvements to existing OpenCode slash commands: adding a standup-readable section to `/weekly-summary`, making `/specify` ask more thorough clarifying questions, and making `/fix-conflict` automatically continue the git operation after resolving conflicts.

## Architecture

All three tasks modify markdown command definitions in `src/opencode/command/`. These are declarative instruction files that control LLM behavior — no code logic, no runtime dependencies. Each can be edited independently.

## Data flow

N/A — these are LLM instruction files, not data-processing code.

## Tasks

### Task 1: Add standup-readable section to weekly-summary

- **File**: `src/opencode/command/weekly-summary.md`
- **Change**: Add a new output section after the detailed summary that provides a concise, first-person standup script the user can read aloud. Format: 2-3 sentences per ticket covering what was done and current status. Include a "Standup Script" heading in the output template.
- **Dependencies**: None
- **Complexity**: Small
- **Parallel**: Yes
- **Todoist**: https://app.todoist.com/app/task/make-the-summary-have-a-part-where-i-can-read-to-standup-6gXrj8VF8x9Fpwwv

### Task 2: Make specify ask more thorough questions

- **File**: `src/opencode/command/specify.md`
- **Change**: Enhance the "Post-Specification Clarification" section to be more aggressive about questioning. Currently it only iterates open questions from the spec. Add instructions to:
  1. Before writing the spec, do a pre-analysis pass asking the user about ambiguous requirements, scope boundaries, and implementation preferences
  2. For each task in the spec, generate at least one question about acceptance criteria, edge cases, or expected behavior
  3. Group questions by priority: blocking (must answer before spec) vs informational (can answer later)
  4. Ask about cross-cutting concerns: error handling strategy, logging, backwards compatibility, rollback plan
- **Dependencies**: None
- **Complexity**: Small
- **Parallel**: Yes
- **Todoist**: https://app.todoist.com/app/task/make-the-specify-ask-way-more-questions-about-all-tasks-and-features-6gXrrr5CjQf8m6Mv

### Task 3: Make fix-conflict auto-continue after resolution

- **File**: `src/opencode/command/fix-conflict.md`
- **Change**: Replace step 4 ("Do NOT commit or continue") with logic that automatically continues the operation:
  1. After all conflicts are resolved, staged, and verification passes, detect the operation type from `git status`
  2. For merge: run `git commit --no-edit` (uses the default merge commit message)
  3. For rebase: run `git rebase --continue`
  4. For cherry-pick: run `git cherry-pick --continue`
  5. If the continue triggers new conflicts, loop back to step 2 (resolve again)
  6. If verification (lint/tests) failed, still stop and ask the user before continuing
  7. Report what operation was completed in the summary
- **Dependencies**: None
- **Complexity**: Small
- **Parallel**: Yes
- **Todoist**: https://app.todoist.com/app/task/make-fix-conflict-automatically-continue-once-done-6gXrxwwPqc9rfJ8M

## API contracts

N/A — no new interfaces or contracts.

## State changes

N/A — no new config, env vars, or stored state.

## Edge cases

- **fix-conflict auto-continue**: A rebase may have multiple conflict rounds. The command must loop until no more conflicts remain or a non-conflict error occurs.
- **fix-conflict auto-continue**: If lint/tests fail after resolution, the command should NOT auto-continue — it should stop and let the user decide.
- **specify questioning**: Questions should not be redundant with what the user already specified in their arguments. Skip questions whose answers are already clear from context.
- **weekly-summary standup**: If there are no tickets (only unlinked commits), the standup script should still be generated summarizing the commits.

## Testing approach

Manual testing only — these are markdown instruction files. Verify by running each command after editing and confirming the new behavior.

## Decisions

1. **Standup script tone**: Decision: First-person ("I worked on X, moved it to QA")
2. **Standup script length**: Decision: Include all tickets, one line each
3. **fix-conflict loop limit**: Decision: No limit — keep resolving until done or a non-conflict error occurs
4. **fix-conflict rollback**: Decision: Yes, offer `git rebase --abort` if auto-continue fails with a non-conflict error
