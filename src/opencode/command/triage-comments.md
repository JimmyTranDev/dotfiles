---
name: triage-comments
description: Walk through PR review comments one by one with fix, reply, skip, or custom action per comment
---

Usage: /triage-comments [PR URL or number]

$ARGUMENTS

Fetch PR review comments and walk through each unresolved one interactively. For each comment you can apply a code fix, post a reply, skip, or give a custom instruction. No reply is ever posted to GitHub until you explicitly approve it.

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
   - **Yes, include bot comments** — include them in the triage loop
   - **No, skip bot comments** — filter them out

Load skills in parallel: **comm-natural-speech**, **code-follower**, **git-workflows**.

## Triage Loop

For each unresolved comment, show:
- The reviewer's name (and whether it is a bot)
- The file and line location
- The full comment text
- The code snippet being discussed

Then present options using the question tool:
- **Fix** — apply the code fix immediately, then move to the next comment
- **Reply** — draft a reply for approval before posting (see Reply Approval below)
- **Skip** — move to the next comment without action

The user can also type a custom response to provide specific instructions for how to handle the comment (e.g., "fix it but use a different approach", "reply saying we'll address in a follow-up").

When **Fix** is selected, launch the **fixer** agent on that comment and apply the change before moving on.

When a custom response is provided, interpret it as instructions and act accordingly. If the instruction results in a reply being posted to GitHub, it must go through the Reply Approval step first.

## Voice Learning

Reply suggestions must sound like the user, not like a generic bot. Continuously learn the user's voice from their own inputs during the session:

- Before generating suggestions, gather voice samples from:
  - Any custom replies the user typed earlier in this session (highest signal — these are their exact words)
  - The user's own past replies on this PR (from `fetch-pr-comments.sh` output, filtered to the PR author / current user via `gh api user -q .login`)
  - The user's custom instructions and phrasing in this conversation
- Extract and mirror their style: typical sentence length, formality, greetings/sign-offs, use of contractions, emoji or none, casing, hedging vs directness, common phrases, and language (e.g., English vs Norwegian).
- Each time the user types a custom reply or edits a suggestion, treat it as new training signal — update the inferred style and apply it to all later suggestions in the session.
- Do not over-fit from a single sample. If there is little signal, default to the **comm-natural-speech** skill's natural phrasing.
- Never invent facts to match a tone — match voice, not content.

## Reply Approval

Replies are NEVER posted to GitHub without explicit user approval.

1. Generate 2-3 context-aware reply suggestions in the user's learned voice and present them using the question tool:
   1. First suggested reply
   2. Second suggested reply
   3. Third suggested reply (if applicable)
   4. **Skip** — move to the next comment without replying

   The `custom` flag is enabled, so the user can also type their own reply.

2. After a reply is chosen or written, show the exact final reply text and ask for explicit approval using the question tool:
   - **Post this reply** — post it to GitHub
   - **Edit** — revise the reply text, then ask for approval again
   - **Cancel** — discard the reply and move to the next comment

3. Only after **Post this reply** is selected, post it via:
   `gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies -f body="<reply>"`

## Summary

After all comments have been triaged, present final results:
- X comments fixed
- Y comments replied to
- Z comments skipped
- W comments handled with custom action
- Remaining unresolved: N

If any fixes were made, ask if the user wants to:
- **Commit and push** — stage all changes, commit with a descriptive message, and push
- **Just commit** — stage and commit without pushing
- **Leave unstaged** — let the user handle git manually

## Rules

- Never post a reply or comment to GitHub until the user explicitly approves the exact reply text.
- Never resolve or close review threads — only reply. Let the reviewer resolve their own threads.
- Each reply must be specific — never post generic "Addressed in <sha>" messages.
- Replies must feel personal and natural — vary phrasing, avoid repetitive patterns across comments.
- Suggestions must mirror the user's own voice, learned from their inputs in the session (see Voice Learning). Update the inferred style every time the user types or edits a reply.
- Never force push unless explicitly asked.
