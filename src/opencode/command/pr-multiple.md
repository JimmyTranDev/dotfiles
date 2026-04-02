---
name: pr-multiple
description: Implement multiple independent changes in parallel worktrees and create a PR for each
---

Usage: /pr-multiple <list of changes to implement>

Implement multiple independent changes simultaneously, each in its own git worktree, then create a pull request for each.

$ARGUMENTS

Load the **worktree-workflow** and **git-workflows** skills in parallel.

1. Parse the task list from `$ARGUMENTS`:
   - Split the input into individual change descriptions (separated by newlines, numbered lists, commas, or semicolons)
   - Each item becomes an independent unit of work with its own branch and PR
   - If only one item is detected, notify the user and suggest using `/pr` instead, then stop

2. Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

3. Derive a kebab-case branch name for each task (e.g., `feat-add-dark-mode`, `fix-login-redirect`). Keep them short and descriptive.

4. Check for uncommitted changes (run in parallel):
   - `git status --porcelain`
   - `git diff --cached --stat`

5. If there are staged or unstaged changes:
   - Stash them with `git stash push -m "pr-multiple-stash"`

6. Create all worktrees in parallel:
   - For each task: `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`
   - If any worktree creation fails, report the error for that task and continue with the rest

7. Implement all changes in parallel — launch a separate **general** agent for each task:
   - Each agent receives its task description and worktree path (`~/Programming/wcreated/<branch-name>/`)
   - Each agent implements the changes, stages, and commits using the format from the **git-workflows** skill
   - Each agent works exclusively in its own worktree directory
   - Wait for all agents to complete before proceeding

8. Review all worktrees in parallel — for each completed worktree, launch **reviewer**, **auditor**, and **tester** agents in parallel:
   - All three agents analyze the diff from `git diff <base-branch>...HEAD` in the worktree
   - **reviewer**: catches bugs, design issues, and code quality problems
   - **auditor**: scans for security vulnerabilities and exploitable patterns
   - **tester**: verifies test coverage and adds missing tests for the new changes
   - Collect all issues found across all worktrees

9. Fix issues in parallel — for each worktree with issues:
   - Launch **fixer** agents in parallel for independent fixes across different worktrees
   - After fixes are applied in a worktree, stage and commit: `git add -A && git commit -m "🐛 fix: address review and audit findings"`
   - Run **reviewer** once more per worktree to verify fixes (max 2 iterations per worktree)

10. Push all branches and create PRs in parallel:
     - For each worktree:
       - `git push -u origin <branch-name>`
       - Create the PR with `gh pr create` targeting the base branch, with a title matching the original commit message and a summary body
    - Collect all PR URLs

11. Report outcome to the user:
    - Table of all tasks with their branch name, PR URL, and status (success/failed)
    - Count of PRs created vs failed
    - If changes were stashed in step 5, remind the user to `git stash pop` in the main repo

Important:
- All work happens in worktree directories, never in the main repo
- Each task is fully independent — a failure in one task does not block others
- If a stash pop has conflicts, notify the user and stop before creating worktrees
- If `gh pr create` fails for a task, report the error for that task but continue with others
- Do not modify the main repo's working tree
- Maximize parallelism at every step — never serialize independent operations
