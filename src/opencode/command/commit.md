---
name: commit
model: claude-haiku-4.5
description: Create a well-formatted git commit using conventional commit format
---

Review my staged changes and create a well-formatted git commit.

Format: `<type>(<scope>): <emoji> <description>`

Commit type/emoji mapping (keys match nvim `<Leader>gc*` keymaps):

| Key | Type | Emoji |
|-----|------|-------|
| `f` | `feat` | `✨` |
| `F` | `fix` | `🐛` |
| `c` | `chore` | `🔧` |
| `r` | `refactor` | `🔨` |
| `d` | `docs` | `📚` |
| `s` | `style` | `💎` |
| `t` | `test` | `🧪` |
| `p` | `perf` | `🚀` |
| `b` | `build` | `📦` |
| `a` | `ci` | `👷` |
| `R` | `revert` | `⏪` |

Important:
- Only commit the files that are already staged (shown in `git diff --cached`)
- Do NOT stage any additional files - only commit what is already staged
- If no files are staged, notify the user and do not create a commit

Analyze the staged changes (git diff --cached -- . ':!*.csv') to understand the changes, then create the commit. Always exclude `*.csv` files from diff output — CSV diffs are large, noisy, and not useful for understanding changes.
