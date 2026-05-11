---
name: triage-comments
description: Walk through PR review comments one by one and interactively decide how to handle each
---

Usage: /triage-comments [PR URL or number]

$ARGUMENTS

Fetch PR review comments and walk through each unresolved one interactively, letting the user decide the action for each.

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

## Triage Loop

For each unresolved comment, show:
- The reviewer's name
- The file and line location
- The full comment text
- The code snippet being discussed

Then present options using the question tool:

- **Fix it** — launch the **fixer** agent to address the feedback
- **Skip** — move to the next comment without action
- **Stop** — end triage, skip remaining comments

## After Each Fix

1. Show what changed (brief diff summary)

## Summary

After all comments are processed (or user stops), present:
- X comments fixed
- Z comments skipped

If any fixes were made, ask if the user wants to:
- **Commit and push** — stage all changes, commit with a descriptive message, and push
- **Just commit** — stage and commit without pushing
- **Leave unstaged** — let the user handle git manually

## Rules

- Never resolve or close review threads — only reply. Let the reviewer resolve their own threads.
- Load **comm-natural-speech** skill before writing replies. Replies must feel personal and natural — vary phrasing, avoid repetitive patterns across comments. Reference the specific change made, not boilerplate responses.
- Never force push unless explicitly asked.
- Load **code-follower** skill before making fixes to match codebase conventions.
- Load **git-workflows** skill for commit message formatting.
