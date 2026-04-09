---
name: pr-multiple
description: Group related changes to reduce conflicts, implement in parallel worktrees, and create a PR per group
---

Usage: /pr-multiple <list of changes to implement>

Parse individual tasks from `$ARGUMENTS`, group tasks that would touch overlapping files into the same PR, then implement each group in its own worktree and create one pull request per group.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **todoist-cli** skills in parallel.

1. Parse the task list from `$ARGUMENTS`:
   - Split the input into individual change descriptions (separated by newlines, numbered lists, commas, or semicolons)
   - Each item is a discrete unit of work
   - If only one item is detected, notify the user and suggest using `/pr` instead, then stop

2. Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

3. Group tasks to reduce conflicts:
   - For each task, predict which files or directories it will modify based on the task description and codebase structure (use the **explore** agent if needed)
   - Build a file-overlap graph: two tasks overlap if their predicted file sets share any file or parent directory
   - Merge overlapping tasks into the same group using union-find — tasks that share files with a common task end up in one group
   - Tasks with no predicted overlap remain in their own group
   - Present the proposed grouping to the user and ask for confirmation before proceeding. Show each group with its tasks and predicted files. The user can accept, adjust groups manually, or override to one-task-per-PR mode

4. Derive a kebab-case branch name for each **group** (e.g., `feat-settings-improvements`, `fix-auth-and-redirect`). Use a name that summarizes the group's combined purpose. Keep them short and descriptive.

5. Check for uncommitted changes (run in parallel):
   - `git status --porcelain`
   - `git diff --cached --stat`

6. If there are staged or unstaged changes:
   - Stash them with `git stash push -m "pr-multiple-stash"`

7. Create all worktrees in parallel (one per group):
   - For each group: `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`
   - If any worktree creation fails, report the error for that group and continue with the rest

8. Process all groups in parallel — launch a separate **general** agent for each group. Each agent handles the full lifecycle for its group independently:

   a. **Implement**: Apply all tasks in the group sequentially within the same worktree. Stage and commit each task individually using the format from the **git-workflows** skill (one commit per task, so the PR history stays granular).

   b. **Review**: Launch **reviewer**, **auditor**, and **tester** agents in parallel on the full diff from `git diff <base-branch>...HEAD`:
      - **reviewer**: catches bugs, design issues, and code quality problems
      - **auditor**: scans for security vulnerabilities and exploitable patterns
      - **tester**: verifies test coverage and adds missing tests for the new changes

   c. **Fix**: If issues were found, launch **fixer** to address them, then stage and commit: `git add -A && git commit -m "🐛 fix: address review and audit findings"`. Run **reviewer** once more to verify (max 2 iterations).

   d. **Push**: Push the branch with `git push -u origin <branch-name>`

   e. **Create PR**: Create the PR with `gh pr create` targeting the base branch. Title summarizes the group. Body lists each task as a checklist item with its individual commit hash.

   f. **Complete Todoist tasks**: For each task in the group that contains a Todoist URL (`app.todoist.com/...`), complete it: `td task complete <url>`

   g. **Mark todos**: Mark each task's corresponding TodoWrite entry as `completed` on success or `pending` on failure

   Each agent works exclusively in its own worktree directory (`~/Programming/wcreated/<branch-name>/`). A failure in one group does not block others — all groups run to completion independently.

9. Clean up all worktrees and branches in parallel — for each group (run in parallel):
   - `git worktree remove ~/Programming/wcreated/<branch-name>`
   - `git branch -d <branch-name>`

10. Report outcome to the user:
    - Table showing each group, its tasks, branch name, PR URL, and status (success/failed)
    - Count of PRs created vs failed
    - If changes were stashed in step 6, remind the user to `git stash pop` in the main repo

Important:
- All work happens in worktree directories, never in the main repo
- Each group runs through its full lifecycle (implement, review, fix, push, create PR) independently in parallel
- A failure in one group does not block others — all groups run to completion
- If a stash pop has conflicts, notify the user and stop before creating worktrees
- Do not modify the main repo's working tree
- Grouping happens upfront to prevent conflicts, eliminating the need for post-hoc rebasing
- Within a group, tasks are committed individually to preserve granular history in the PR
