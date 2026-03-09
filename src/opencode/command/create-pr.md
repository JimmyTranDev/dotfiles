---
name: create-pr
description: Create a pull request with auto-generated title and body from branch commits
---

Usage: /create-pr

Create a pull request for the current branch with an auto-generated title and body.

1. Determine the base branch:
   - Check if `develop` branch exists locally or as `origin/develop` — if so, use it as the base
   - Otherwise, fall back to `main` (or `origin/main`)
   - If neither exists, notify the user and stop

2. Gather branch context:
   - Run `git log --oneline <base-branch>..HEAD` to see all commits on this branch
   - Run `git diff <base-branch>...HEAD` to see the full diff
   - Run `git rev-parse --abbrev-ref HEAD` to get the current branch name

3. Check remote status:
   - If the branch is not pushed to remote, push it with `git push -u origin <branch-name>`

4. Generate PR content:
   - **Title**: Derive from the branch name or commit messages — concise, descriptive, no ticket prefix unless present in branch name
   - **Body**: Summarize the changes in a `## Summary` section with 1-5 bullet points describing what was done and why
   - If a Jira ticket ID is found in the branch name (pattern `[A-Z]+-[0-9]+`), include it in the body

5. Create the PR:
   - Use `gh pr create --base <base-branch> --title "<title>" --body "<body>"`
   - Present the PR URL to the user

6. Load relevant skills where applicable:
   - **git-workflows**: Load for branch naming and PR conventions
