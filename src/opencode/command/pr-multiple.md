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

8. Analyze file overlap and determine merge order:
   - For each worktree, collect the set of changed files: `git diff <base-branch>...HEAD --name-only`
   - Build a dependency graph: two tasks overlap if they modify any of the same files
   - Order tasks so that non-overlapping tasks can merge freely, and overlapping tasks merge sequentially (smallest changeset first to minimize rebase complexity)
   - Group tasks into: **independent** (no file overlap with any other task) and **overlapping** (share files with at least one other task)

9. Review all worktrees in parallel — for each completed worktree, launch **reviewer**, **auditor**, and **tester** agents in parallel:
    - All three agents analyze the diff from `git diff <base-branch>...HEAD` in the worktree
    - **reviewer**: catches bugs, design issues, and code quality problems
    - **auditor**: scans for security vulnerabilities and exploitable patterns
    - **tester**: verifies test coverage and adds missing tests for the new changes
    - Collect all issues found across all worktrees

10. Fix issues in parallel — for each worktree with issues:
    - Launch **fixer** agents in parallel for independent fixes across different worktrees
    - After fixes are applied in a worktree, stage and commit: `git add -A && git commit -m "🐛 fix: address review and audit findings"`
    - Run **reviewer** once more per worktree to verify fixes (max 2 iterations per worktree)

11. Push and rebase to reduce merge conflicts:
    - Push all **independent** branches in parallel: `git push -u origin <branch-name>`
    - For **overlapping** branches, push and rebase sequentially in the determined merge order:
      a. Push the first overlapping branch: `git push -u origin <branch-name>`
      b. For each subsequent overlapping branch:
         - In its worktree, fetch and rebase onto the previously pushed branch: `git fetch origin <previous-branch> && git rebase origin/<previous-branch>`
         - If rebase conflicts occur, load the **git-conflict-resolution** skill, resolve each conflicted file, then `git add <file>` and `git rebase --continue`
         - Push the rebased branch: `git push -u origin <branch-name>`
    - This ensures each overlapping PR already incorporates the changes from earlier PRs, preventing conflicts at merge time

12. Create PRs in parallel:
    - For each worktree:
      - Create the PR with `gh pr create` targeting the base branch, with a title matching the original commit message and a summary body
    - Collect all PR URLs

13. Mark todos as completed:
    - If this command was invoked from a todo list (i.e., there are existing todos tracked via TodoWrite), mark the corresponding todo item(s) as `completed`
    - Mark each successfully completed task as `completed` in the todo list
    - Mark any failed tasks as `pending` so they can be retried

14. Report outcome to the user:
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
- Overlapping branches are rebased sequentially to prevent merge conflicts when PRs are merged into the base branch
- The merge order (smallest changeset first) minimizes rebase conflict complexity
