---
name: commit-summary
description: Generate a summary of recent commits grouped by type, with optional PR links
---

Usage: /commit-summary [$ARGUMENTS]

Generate a human-readable summary of recent commits, grouped by type/scope, and dump to a markdown file.

1. Determine date range:
   - If `$ARGUMENTS` contains dates (e.g., "last week", "2026-04-01..2026-04-29"), use those
   - If `$ARGUMENTS` contains a number (e.g., "30"), use the last N days
   - If no arguments, ask the user to select via the question tool: "Today", "This week", "This month", "Custom range"

2. Gather commits:
   - Run `git log --oneline --after=<start> --before=<end>` for the selected range
   - If the range returns no commits, report empty and exit

3. Gather PR links (if available):
   - For each commit, check if it's associated with a PR: `gh pr list --search "<commit-hash>" --json number,url`
   - Attach PR links to commits where found

4. Group and summarize:
   - Parse commit messages by type (feat, fix, refactor, chore, docs, etc.) using the emoji/prefix convention
   - Group by scope (e.g., opencode, zsh, yazi)
   - Within each group, list commits with their description and PR link if available

5. Write to markdown file:
   - Filename: `commit-summary-<start>-to-<end>.md` (e.g., `commit-summary-2026-04-01-to-2026-04-29.md`)
   - Format:
     ```markdown
     ## Features
     - **opencode**: Add critic and fullstacker agents ([PR #42](url))
     - **yazi**: Add spec folder shortcuts

     ## Fixes
     - **zsh**: Fix tty handling for fzf

     ## Refactoring
     - **opencode**: Consolidate command families
     ```

6. Report:
   - Path to the generated file
   - Total commits summarized
   - Breakdown by type
