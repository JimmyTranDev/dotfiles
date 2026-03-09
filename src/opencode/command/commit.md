---
name: commit
description: Create a well-formatted git commit with emoji prefix and conventional format
---

Review my staged changes and create a well-formatted git commit.

Format: `<emoji> <type>(<scope>): <description>` — use the emoji mapping from the `git-workflows` skill.

Important:
- Only commit the files that are already staged (shown in `git diff --cached`)
- Do NOT stage any additional files - only commit what is already staged
- If no files are staged, notify the user and do not create a commit
- Ignore any files with `-actx` suffix (these are temporary symlinks)

Analyze the staged changes (git diff --cached) to understand the changes, then create the commit.
