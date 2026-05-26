---
name: triage-comments
description: Walk through PR review comments one by one, collect decisions, then execute all fixes in batch
---

Usage: /triage-comments [PR URL or number]

$ARGUMENTS

Fetch PR review comments and walk through each unresolved one interactively, collecting all decisions first, then executing fixes in batch.

## Setup

1. Determine the PR:
   - If `$ARGUMENTS` contains a PR URL or number, use that
   - Otherwise, use the current branch's PR via `gh pr view`
   - If no PR exists, notify the user and stop

2. Fetch all review context in parallel:
   - `gh api repos/{owner}/{repo}/pulls/{number}/comments` for inline comments
   - `gh pr view --json comments,reviews` for PR-level comments
   - `git diff $(gh pr view --json baseRefName -q .baseRefName)...HEAD` for the current diff

3. Filter to unresolved comments only. Group them by file, then present them in file order (top to bottom).

Load skills in parallel: **comm-natural-speech** (for writing replies), **code-follower** (for matching codebase conventions during fixes), **git-workflows** (for commit message formatting).

## Phase 1: Collect Decisions

For each unresolved comment, show:
- The reviewer's name
- The file and line location
- The full comment text
- The code snippet being discussed

Then present options using the question tool:

- **Fix it** — mark for fixing in batch
- **Reply only** — mark for reply without code change
- **Skip** — move to the next comment without action
- **Stop** — skip all remaining comments, proceed to Phase 2

Do NOT execute any fixes during this phase.

## Phase 2: Confirm Plan

After all decisions are collected (or the user stops), present a summary:

```
## Triage Plan
- X comments to fix
- Y comments to reply to
- Z comments skipped

### Will Fix:
1. [file:line] — [comment summary]
2. [file:line] — [comment summary]

### Will Reply:
1. [file:line] — [reply summary]
```

Ask the user to confirm: **Execute plan**, **Revise** (go back and change decisions), or **Cancel**.

## Phase 3: Execute

After confirmation:

1. **Fixes**: Launch the **fixer** agent for each comment marked "Fix". Run independent fixes in parallel where they affect different files. Show what changed after each fix.
2. **Replies**: Post reply comments for items marked "Reply only".

## Phase 4: Summary

Present final results:
- X comments fixed
- Y comments replied to
- Z comments skipped

If any fixes were made, ask if the user wants to:
- **Commit and push** — stage all changes, commit with a descriptive message, and push
- **Just commit** — stage and commit without pushing
- **Leave unstaged** — let the user handle git manually

## Rules

- Never resolve or close review threads — only reply. Let the reviewer resolve their own threads.
- Replies must feel personal and natural — vary phrasing, avoid repetitive patterns across comments. Reference the specific change made, not boilerplate responses.
- Never force push unless explicitly asked.
