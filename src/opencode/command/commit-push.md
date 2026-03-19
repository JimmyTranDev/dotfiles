---
name: commit-push
description: Create a well-formatted git commit and push to remote
---

Review my staged changes, create a well-formatted git commit, and push to the remote.

Format: `<emoji> <type>(<scope>): <description>` — use the emoji mapping from the `git-workflows` skill.

Important:
- Only commit the files that are already staged (shown in `git diff --cached`)
- Do NOT stage any additional files - only commit what is already staged
- If no files are staged, notify the user and do not create a commit

1. Analyze the staged changes (git diff --cached) to understand the changes, then create the commit
2. After a successful commit, push to the remote with `git push`
3. If the push fails, notify the user with the error details
