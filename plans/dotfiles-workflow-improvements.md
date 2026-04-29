## Overview

Improvements to existing OpenCode command workflows: mandatory `/clarify` before `/implement`, PR comment answer saving, PR comment fix improvements, and `/implement` cleaning up plans after completion.

## Architecture

These modify existing command files at `src/opencode/command/` and the shared conventions in `src/opencode/AGENTS.md`. Changes are small edits to instruction text, not new files.

## Data flow

- Clarify enforcement: `/implement` checks if clarify was run (or asks user to confirm requirements are clear)
- Comment saving: `/fix-pr` writes skipped comment explanations to `comments.md`
- Plan cleanup: `/implement` deletes the plan file from `plans/` after all tasks are complete

## Tasks

### 1. Mandatory `/clarify` before `/implement`
- **File**: `src/opencode/command/implement.md` (modify)
- **Changes**: Add a preamble step: before starting implementation, check if a plan/spec exists or ask the user to confirm requirements are clear. If ambiguous, suggest running `/clarify` first. Not a hard block — a prompt with option to skip.
- **Complexity**: small
- **Parallel**: yes

### 2. Save skipped PR comment answers to `comments.md`
- **File**: `src/opencode/command/fix-pr.md` (modify)
- **Changes**: When processing PR review comments, if the user chooses to skip a suggestion, prompt for a reason and append it to `comments.md` in the project root. Format: `## PR #<number> - <date>\n### <comment summary>\n<reason for skipping>`
- **Complexity**: small
- **Parallel**: yes

### 3. Improve PR comment fix with clarify and answer
- **File**: `src/opencode/command/fix-pr.md` (modify)
- **Changes**: Before applying fixes, run a clarification step on ambiguous review comments. For each unclear comment, ask the user what the reviewer meant. After fixing, reply to the PR comment via `gh` CLI explaining what was done.
- **Dependencies**: Task 2 (same file, apply sequentially)
- **Complexity**: medium
- **Parallel**: no (depends on task 2)

### 4. `/implement` removes plans after completion
- **File**: `src/opencode/command/implement.md` (modify)
- **Changes**: After all tasks in a plan are implemented and committed, delete the plan file from `plans/`. Ask for confirmation first. If the plan was split across multiple files, only delete the one that was fully implemented.
- **Dependencies**: Task 1 (same file, apply sequentially)
- **Complexity**: small
- **Parallel**: no (depends on task 1)

## API contracts

N/A — these are instruction modifications, not code interfaces.

## State changes

- Task 2: Creates/appends to `comments.md` in project root
- Task 4: Deletes files from `plans/`

## Edge cases

- Task 1: User runs `/implement` with a clear, unambiguous one-liner — don't force clarification
- Task 2: `comments.md` doesn't exist yet — create it with a header
- Task 3: PR has no review comments — skip the clarification step
- Task 4: Plan file was partially implemented — don't delete, mark completed tasks

## Testing approach

Manual testing: run each modified command and verify the new behavior.

## Decisions (resolved)

- Task 1: Soft prompt — suggest `/clarify`, let user skip with one click
- Task 3: Show reply text for user approval before posting to PR
