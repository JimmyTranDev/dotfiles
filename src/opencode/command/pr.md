---
name: pr
description: Implement changes in a worktree and create a PR
---

Usage: /pr <description of what to implement>

Implement the described changes in a new git worktree, then create a pull request.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **todoist-cli** skills in parallel.

1. Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

2. Derive a kebab-case branch name from the task description (e.g., `feat-add-dark-mode`, `fix-login-redirect`). Keep it short and descriptive.

3. Check for uncommitted changes (run in parallel):
   - `git status --porcelain`
   - `git diff --cached --stat`

4. If there are staged or unstaged changes:
   - Stash them with `git stash push -m "<branch-name>"`

5. Create the worktree:
   - `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

6. If changes were stashed in step 4:
   - Apply the stash in the worktree: `git stash pop` (run from the worktree directory)

7. Implement the requested changes — all file reads, edits, and creates happen in `~/Programming/wcreated/<branch-name>/`, not the main repo

8. Stage and commit the changes using the commit format from the **git-workflows** skill:
   - `git add -A`
   - `git commit -m "<emoji> <type>(<scope>): <description>"`

9. Review — launch **reviewer**, **auditor**, and **tester** agents in parallel on the diff from `git diff <base-branch>...HEAD`:
   - **reviewer**: catches bugs, design issues, and code quality problems
   - **auditor**: scans for security vulnerabilities and exploitable patterns
   - **tester**: verifies test coverage and adds missing tests for the new changes

10. If issues were found:
    - Launch **fixer** agents in parallel for independent fixes across different files
    - After fixes are applied, stage and commit: `git add -A && git commit -m "🐛 fix: address review and audit findings"`
    - Run **reviewer** once more to verify the fixes are correct — if new issues are found, repeat this step (max 2 iterations)

11. Push the branch:
    - `git push -u origin <branch-name>`

12. Create the PR:
    - Create the PR with `gh pr create` targeting the base branch, with a title matching the original commit message and a summary body

13. If `$ARGUMENTS` contains a Todoist URL (`app.todoist.com/...`), complete the task: `td task complete <url>`

14. Report the PR URL to the user

Important:
- All work happens in the worktree directory, never in the main repo
- If a stash pop has conflicts, notify the user and stop
- If `gh pr create` fails, report the error but do not retry
- Do not modify the main repo's working tree
