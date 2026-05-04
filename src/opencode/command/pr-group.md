---
name: pr-group
description: Group related changes to reduce conflicts, implement in parallel worktrees, and create a PR per group
---

Usage: /pr-group <list of changes to implement>

Parse individual tasks from `$ARGUMENTS`, group tasks that would touch overlapping files into the same PR, then implement each group in its own worktree and create one pull request per group.

$ARGUMENTS

Load the **git-worktree-workflow**, **git-workflows**, and **tool-todoist-cli** skills in parallel.

1. Parse the task list from `$ARGUMENTS`:
   - Split the input into individual change descriptions (separated by newlines, numbered lists, commas, or semicolons)
   - If the input contains Jira URLs (e.g., `*.atlassian.net/browse/*`) or Jira ticket IDs (e.g., `ABC-123`), treat each ticket as a separate task. Fetch each ticket's details using `acli jira workitem view <TICKET-ID> --fields "summary,description,status,priority"` to get the full task description.
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

5. Set up all worktrees per the `pr-*` conventions in AGENTS.md (one per group, created in parallel):
   - For each group: `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`
   - If any worktree creation fails, report the error for that group and continue with the rest

6. Process all groups in parallel — launch a separate **general** agent for each group. Each agent handles the full lifecycle for its group independently:

   a. **Implement**: Apply all tasks in the group sequentially within the same worktree. Stage and commit each task individually using the format from the **git-workflows** skill (one commit per task, so the PR history stays granular).

   b. **Review**: Run the review-fix-verify cycle per the `pr-*` conventions in AGENTS.md

   c. **Push**: Push the branch with `git push -u origin <branch-name>`

   d. **Create PR**: Create the PR with `gh pr create` targeting the base branch. Title summarizes the group. Body lists each task as a checklist item with its individual commit hash.

   e. **Mark todos**: Mark each task's corresponding TodoWrite entry as `completed` on success or `pending` on failure

   Each agent works exclusively in its own worktree directory (`~/Programming/wcreated/<branch-name>/`). A failure in one group does not block others — all groups run to completion independently.

7. Report outcome to the user:
    - Table showing each group, its tasks, branch name, PR URL, and status (success/failed)
    - Count of PRs created vs failed
    - If changes were stashed during worktree setup, remind the user to `git stash pop` in the main repo

Important:
- Each group runs through its full lifecycle (implement, review, fix, push, create PR) independently in parallel
- A failure in one group does not block others — all groups run to completion
- Grouping happens upfront to prevent conflicts, eliminating the need for post-hoc rebasing
- Within a group, tasks are committed individually to preserve granular history in the PR
