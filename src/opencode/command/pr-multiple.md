---
name: pr-multiple
description: Implement multiple independent changes in parallel worktrees and create a PR for each
---

Usage: /pr-multiple <list of changes to implement>

Implement multiple independent changes simultaneously, each in its own git worktree, then create a pull request for each.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **todoist-cli** skills in parallel.

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

7. Process all tasks in parallel — launch a separate **general** agent for each task. Each agent handles the full lifecycle for its task independently:

   a. **Implement**: Apply the changes in the worktree, stage, and commit using the format from the **git-workflows** skill

   b. **Review**: Launch **reviewer**, **auditor**, and **tester** agents in parallel on the diff from `git diff <base-branch>...HEAD`:
      - **reviewer**: catches bugs, design issues, and code quality problems
      - **auditor**: scans for security vulnerabilities and exploitable patterns
      - **tester**: verifies test coverage and adds missing tests for the new changes

   c. **Fix**: If issues were found, launch **fixer** to address them, then stage and commit: `git add -A && git commit -m "🐛 fix: address review and audit findings"`. Run **reviewer** once more to verify (max 2 iterations).

   d. **Push**: Push the branch with `git push -u origin <branch-name>`

   e. **Create PR**: Create the PR with `gh pr create` targeting the base branch, with a title matching the original commit message and a summary body

    f. **Complete Todoist task**: If the task description contains a Todoist URL (`app.todoist.com/...`), complete the task: `td task complete <url>`

    g. **Mark todo**: If this task has a corresponding todo tracked via TodoWrite, mark it as `completed` on success or `pending` on failure

   Each agent works exclusively in its own worktree directory (`~/Programming/wcreated/<branch-name>/`). A failure in one task does not block others — all tasks run to completion independently.

8. Analyze file overlap and rebase overlapping branches:
   - After all agents complete, collect the set of changed files per branch: `git diff <base-branch>...HEAD --name-only`
   - Identify **overlapping** branches (those that modified any of the same files)
   - For overlapping branches, rebase sequentially (smallest changeset first) to reduce merge conflicts:
     a. For each subsequent overlapping branch:
        - In its worktree, fetch and rebase onto the previously pushed branch: `git fetch origin <previous-branch> && git rebase origin/<previous-branch>`
        - If rebase conflicts occur, load the **git-conflict-resolution** skill, resolve each conflicted file, then `git add <file>` and `git rebase --continue`
        - Force push the rebased branch: `git push --force-with-lease`

9. Clean up all worktrees and branches in parallel — for each task (run in parallel):
   - `git worktree remove ~/Programming/wcreated/<branch-name>`
   - `git branch -d <branch-name>`

10. Report outcome to the user:
    - Table of all tasks with their branch name, PR URL, and status (success/failed)
    - Count of PRs created vs failed
    - If changes were stashed in step 5, remind the user to `git stash pop` in the main repo

Important:
- All work happens in worktree directories, never in the main repo
- Each task runs through its full lifecycle (implement, review, fix, push, create PR) independently in parallel
- A failure in one task does not block others — all tasks run to completion
- If a stash pop has conflicts, notify the user and stop before creating worktrees
- Do not modify the main repo's working tree
- Overlapping branches are rebased sequentially after all tasks complete to reduce merge conflicts at merge time
