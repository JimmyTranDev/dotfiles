---
name: review
description: Review local uncommitted changes or a PR diff for correctness and quality
---

Usage: /review [PR URL or file path]

$ARGUMENTS

## Mode Detection

Parse `$ARGUMENTS` to determine what to review:
- **PR mode** — argument is a GitHub PR URL or PR number → fetch the PR diff and review it
- **Local mode** — no arguments, or argument is a file/directory path → review local uncommitted changes
- If no arguments and no local changes exist, ask the user what they want reviewed

## Local Mode

1. Run `git diff` and `git diff --cached` to gather all staged and unstaged changes
2. If no changes exist, notify the user and stop
3. Load the **code-follower** skill to understand existing conventions
4. Launch the **reviewer** agent on the combined diff with instructions to:
   - Check for bugs, logic errors, and edge cases
   - Verify naming and style matches existing conventions
   - Identify any security concerns
   - Suggest improvements ranked by severity
5. Present findings grouped by file, with severity indicators (critical/warning/suggestion)
6. Do NOT auto-stage or commit anything — this is review-only

## PR Mode

1. Fetch the PR diff using `gh pr diff <ref>`
2. Load the **code-follower** skill
3. Launch the **reviewer** and **auditor** agents in parallel on the diff
4. Present combined findings grouped by file, deduplicated, ranked by severity
