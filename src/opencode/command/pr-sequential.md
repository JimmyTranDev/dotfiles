---
name: pr-sequential
description: Create a worktree and PR upfront, then implement tasks sequentially, pushing and updating the PR after each
---

Usage: /pr-sequential <ordered list of changes to implement>

Create a single worktree and PR upfront with all tasks listed in the description, then implement each task sequentially — pushing a commit and updating the PR description to reflect progress after each completed task.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, and **todoist-cli** skills in parallel.

1. Parse the ordered task list from `$ARGUMENTS`:
   - Split the input into individual change descriptions (separated by newlines, numbered lists, commas, or semicolons)
   - Preserve the order — tasks are implemented sequentially
   - If only one item is detected, notify the user and suggest using `/pr` instead, then stop

2. Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

3. Derive a single kebab-case branch name from the overall task description (e.g., `feat-add-user-settings`). Keep it short and descriptive.

4. Check for uncommitted changes (run in parallel):
   - `git status --porcelain`
   - `git diff --cached --stat`

5. If there are staged or unstaged changes:
   - Stash them with `git stash push -m "<branch-name>"`

6. Create the worktree:
   - `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

7. If changes were stashed in step 5:
   - Apply the stash in the worktree: `git stash pop` (run from the worktree directory)

8. Create an initial empty commit and push:
   - `git commit --allow-empty -m "🚧 chore: initialize <branch-name>"`
   - `git push -u origin <branch-name>`

9. Create the PR with `gh pr create` targeting the base branch:
   - Title: a concise summary of the overall goal
   - Body: a checklist of all tasks with unchecked boxes, e.g.:
     ```
     ## Tasks
     - [ ] Task 1 description
     - [ ] Task 2 description
     - [ ] Task 3 description
     ```

10. Process each task sequentially — for task N (starting at 1):

    a. **Implement**: Apply the changes in the worktree directory (`~/Programming/wcreated/<branch-name>/`), stage, and commit using the format from the **git-workflows** skill:
       - `git add -A`
       - `git commit -m "<emoji> <type>(<scope>): <description>"`

    b. **Review**: Launch **reviewer**, **auditor**, and **tester** agents in parallel on the diff from `git diff HEAD~1...HEAD`

    c. **Fix**: If issues were found, launch **fixer** to address them, then stage and commit: `git add -A && git commit -m "🐛 fix: address review and audit findings"`. Run **reviewer** once more to verify (max 2 iterations).

    d. **Push**: `git push`

    e. **Update PR description**: Use `gh pr edit <pr-number> --body` to update the body, checking off the completed task:
       ```
       ## Tasks
       - [x] Task 1 description
       - [x] Task 2 description
       - [ ] Task 3 description
       ```

    f. **Complete Todoist task**: If the task description contains a Todoist URL (`app.todoist.com/...`), complete the task: `td task complete <url>`

11. **Final review**: Launch the **reviewer** agent on the full PR diff (`git diff <base-branch>...HEAD`) to review the cumulative changes across all tasks. If issues are found, launch **fixer** to address them, commit, and push.

12. Clean up the worktree and branch (run in parallel):
    - `git worktree remove ~/Programming/wcreated/<branch-name>`
    - `git branch -d <branch-name>`

13. Report the PR URL to the user

Important:
- All work happens in the worktree directory, never in the main repo
- A single branch and PR are used for the entire sequence of tasks
- The PR is created upfront so reviewers can follow progress in real time
- After each task, changes are pushed and the PR description is updated to check off the completed task
- If a task fails, ask the user whether to continue with remaining tasks or stop
- If a stash pop has conflicts, notify the user and stop
- Do not modify the main repo's working tree
