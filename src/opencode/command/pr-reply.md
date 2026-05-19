---
name: pr-reply
description: Walk through PR review comments and interactively reply to each one
---

Usage: /pr-reply [PR URL or number]

$ARGUMENTS

Fetch PR review comments and walk through each unresolved one interactively, letting the user choose or write a reply for each.

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

## Reply Loop

For each unresolved comment, show:
- The reviewer's name
- The file and line location
- The full comment text
- The code snippet being discussed

Then generate 3 context-aware response suggestions and present them using the question tool with these options:

1. The first generated reply
2. The second generated reply
3. The third generated reply
4. **Skip** — move to the next comment without replying
5. **Stop** — end the loop, skip remaining comments

The `custom` flag on the question tool is enabled, so the user can also type their own reply.

Post the chosen reply via `gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies -f body="<reply>"`

## Summary

After all comments are processed (or user stops), present:
- X comments replied to
- Y comments skipped
- Remaining unresolved: N

## Rules

- Never resolve or close review threads — only reply. Let the reviewer resolve their own threads.
- Each reply must be specific — never post generic "Addressed in <sha>" messages.
- Load **comm-natural-speech** skill before generating replies. Replies must feel personal and natural — vary phrasing, avoid repetitive patterns across comments.
