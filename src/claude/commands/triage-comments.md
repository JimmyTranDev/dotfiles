---
description: Walk through PR review comments one by one with fix, skip, or custom action per comment
argument-hint: [PR URL or number]
---

Usage: /triage-comments [PR URL or number]

$ARGUMENTS

Fetch PR review comments and walk through each unresolved one interactively, executing fixes immediately.

## Setup

1. Determine the PR:
   - If `$ARGUMENTS` contains a PR URL or number, use that
   - Otherwise, use the current branch's PR via `gh pr view`
   - If no PR exists, notify the user and stop

2. Fetch all review context in parallel:
   - `fetch-pr-comments.sh` to get inline and PR-level comments
   - `git diff $(gh pr view --json baseRefName -q .baseRefName)...HEAD` for the current diff

3. Filter to unresolved comments only. Group them by file, then present them in file order (top to bottom).

Load skills in parallel: **code-follower**, **git-workflows**.

## Triage Loop

For each unresolved comment, show:
- The reviewer's name
- The file and line location
- The full comment text
- The code snippet being discussed

Then present options using the question tool:
- **Fix** — apply the fix immediately, then move to the next comment
- **Skip** — move to the next comment without action

The user can also type a custom response to provide specific instructions for how to handle the comment.

When **Fix** is selected, launch the **fixer** agent on that comment and apply the change before moving on.

When a custom response is provided, interpret it as instructions and act accordingly (e.g., "reply saying we'll address in a follow-up", "fix it but use a different approach", etc.).

## Summary

After all comments have been triaged, present final results:
- X comments fixed
- Y comments skipped
- Z comments handled with custom action

If any fixes were made, ask if the user wants to:
- **Commit and push** — stage all changes, commit with a descriptive message, and push
- **Just commit** — stage and commit without pushing
- **Leave unstaged** — let the user handle git manually

## Rules

- Never resolve or close review threads — only reply. Let the reviewer resolve their own threads.
- Never force push unless explicitly asked.
