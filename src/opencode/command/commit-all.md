---
name: commit-all
description: Stage and commit all files changed during the current session
---

Review all changes made during this session and create a well-formatted git commit including them.

1. Run `git status` to identify all modified, added, and untracked files from the current session
2. Run `git diff` to review unstaged changes
3. Run `git diff --cached` to review any already-staged changes
4. Stage all relevant changed files using `git add` (both modified and new files from this session)
5. Create a well-formatted commit with format: `<emoji> <type>(<scope>): <description>` — use the emoji mapping from the `git-workflows` skill

Important:
- Stage and commit all files that were changed or created during this session
- Do NOT commit files that were not touched in this session
- Do NOT commit files that likely contain secrets (.env, credentials.json, etc.)
- If there are no changes to commit, notify the user and do not create a commit
- Analyze all changes to craft a commit message that accurately describes what was done in the session
