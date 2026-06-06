---
name: commit
model: github-copilot/claude-haiku-4.5
subtask: true
description: Create a well-formatted git commit using conventional commit format
---

Load the **git-workflows** skill for commit message format.

Review my staged changes and create a well-formatted git commit.

Format: `<type>(<scope>): <description>`

Commit types (keys match nvim `<Leader>gc*` keymaps):

| Key | Type |
|-----|------|
| `f` | `feat` |
| `F` | `fix` |
| `c` | `chore` |
| `r` | `refactor` |
| `d` | `docs` |
| `s` | `style` |
| `t` | `test` |
| `p` | `perf` |
| `b` | `build` |
| `a` | `ci` |
| `R` | `revert` |

Important:
- Only commit the files that are already staged (shown in `git diff --cached`)
- Do NOT stage any additional files - only commit what is already staged
- If no files are staged, notify the user and do not create a commit
- Do NOT use emoji in commit messages
- Before composing the commit message, run `git branch --show-current` to get the current branch name. Extract a Jira ticket key matching the pattern `[A-Z]+-[0-9]+` (e.g., `BW-10231`, `PROJ-456`). If found, include the ticket key after the colon-space in the commit message: `<type>(<scope>): TICKET-123 description`. If no ticket is found in the branch name, use the standard format without a ticket.

Analyze the staged changes (git diff --cached -- . ':!*.csv') to understand the changes, then create the commit. Always exclude `*.csv` files from diff output — CSV diffs are large, noisy, and not useful for understanding changes.

Do NOT ask clarifying questions. Decide the commit type, scope, and description autonomously based on the staged diff. Just create the commit immediately.
