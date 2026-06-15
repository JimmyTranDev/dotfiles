---
description: Walk through PR review comments and interactively reply to each one
argument-hint: [PR URL or number]
---

Usage: /pr-reply [PR URL or number]

$ARGUMENTS

Fetch PR review comments and walk through each unresolved one interactively, letting the user select a suggested reply, skip, or write their own.

## Setup

1. Determine the PR:
   - If `$ARGUMENTS` contains a PR URL or number, use that
   - Otherwise, use the current branch's PR via `gh pr view`
   - If no PR exists, notify the user and stop

2. Fetch all review context in parallel:
   - `fetch-pr-comments.sh` to get inline and PR-level comments
   - `git diff $(gh pr view --json baseRefName -q .baseRefName)...HEAD` for the current diff

3. Filter to unresolved comments only. Group them by file, then present them in file order (top to bottom).

4. Check if any comments are from bots (e.g., Copilot, github-actions, dependabot, codecov). If bot comments exist, use the question tool to ask:
   - **Yes, include bot comments** — include them in the reply loop
   - **No, skip bot comments** — filter them out

Load skills in parallel: **comm-natural-speech**, **code-follower**.

## Reply Loop

For each unresolved comment, show:
- The reviewer's name (and whether it is a bot)
- The file and line location
- The full comment text
- The code snippet being discussed

Then generate 2-3 context-aware response suggestions and present them using the question tool:

1. First suggested reply
2. Second suggested reply
3. Third suggested reply (if applicable)
4. **Skip** — move to the next comment without replying

The `custom` flag on the question tool is enabled, so the user can also type their own reply.

Post the chosen reply via `gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies -f body="<reply>"`

## Summary

After all comments are processed, present:
- X comments replied to
- Y comments skipped
- Remaining unresolved: N

## Rules

- Never resolve or close review threads — only reply. Let the reviewer resolve their own threads.
- Each reply must be specific — never post generic "Addressed in <sha>" messages.
- Replies must feel personal and natural — vary phrasing, avoid repetitive patterns across comments.
