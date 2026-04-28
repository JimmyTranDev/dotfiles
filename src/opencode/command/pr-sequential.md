---
name: pr-sequential
description: Create a worktree and PR upfront, then implement tasks sequentially, pushing and updating the PR after each
---

Usage: /pr-sequential <ordered list of changes to implement>

Create a single worktree and PR upfront with all tasks listed in the description, then implement each task sequentially — pushing a commit and updating the PR description to reflect progress after each completed task.

$ARGUMENTS

Load the **git-worktree-workflow**, **git-workflows**, and **tool-todoist-cli** skills in parallel.

1. Parse the ordered task list from `$ARGUMENTS`:
   - Split the input into individual change descriptions (separated by newlines, numbered lists, commas, or semicolons)
   - Preserve the order — tasks are implemented sequentially
   - If only one item is detected, notify the user and suggest using `/pr` instead, then stop

2. Set up the worktree per the `pr-*` conventions in AGENTS.md

3. Create an initial empty commit and push:
    - `git commit --allow-empty --no-verify -m "🔧 chore: initialize <branch-name>"`
   - `git push -u origin <branch-name>`

4. Create the PR with `gh pr create` targeting the base branch:
   - Title: a concise summary of the overall goal
   - Body: a checklist of all tasks with unchecked boxes, followed by a final "Review" task. Each task should have a descriptive summary explaining what will be changed, which files or areas are affected, and what the expected outcome is — not just a short label. The review task is always last. Example:
     ```
     ## Tasks
     - [ ] **Add user settings page** — Create a new `/settings` route with form fields for display name, email preferences, and theme selection. Add validation and wire up to the existing user API.
     - [ ] **Migrate avatar upload to S3** — Replace the local filesystem avatar storage in `UserService` with S3 presigned URLs. Update the upload component to use the new endpoint and add file size/type validation.
     - [ ] **Fix session timeout redirect** — The session expiry handler in `authMiddleware.ts` silently drops the request instead of redirecting to `/login`. Add proper redirect with a return URL parameter.
     - [ ] **Review** — Final review of all cumulative changes across the full PR diff.
     ```

5. Process each task sequentially — for task N (starting at 1):

     a. **Implement**: Apply the changes in the worktree directory (`~/Programming/wcreated/<branch-name>/`), stage, and commit using the format from the **git-workflows** skill (skip hooks during sequential tasks — they run once at the end):
        - `git add -A`
        - `git commit --no-verify -m "<emoji> <type>(<scope>): <description>"`

    b. **Review**: Launch **reviewer**, **auditor**, and **tester** agents in parallel on the diff from `git diff HEAD~1...HEAD`

     c. **Fix**: If issues were found, launch **fixer** agents in parallel for independent fixes across different files, then stage and commit: `git add -A && git commit --no-verify -m "🐛 fix: address review and audit findings"`. Run **reviewer** once more to verify (max 2 iterations).

    d. **Push**: `git push`

    e. **Update PR description**: Use `gh pr edit <pr-number> --body` to update the body, checking off the completed task while preserving the full descriptive summaries:
       ```
       ## Tasks
       - [x] **Add user settings page** — Create a new `/settings` route with form fields for display name, email preferences, and theme selection. Add validation and wire up to the existing user API.
       - [x] **Migrate avatar upload to S3** — Replace the local filesystem avatar storage in `UserService` with S3 presigned URLs. Update the upload component to use the new endpoint and add file size/type validation.
       - [ ] **Fix session timeout redirect** — The session expiry handler in `authMiddleware.ts` silently drops the request instead of redirecting to `/login`. Add proper redirect with a return URL parameter.
       - [ ] **Review** — Final review of all cumulative changes across the full PR diff.
       ```

    f. **Mark todo**: Mark the corresponding TodoWrite todo as `completed` on success or `pending` on failure

6. **Run pre-commit hooks**: Run `git hook run pre-commit` to execute all pre-commit hooks against the current state. If the hooks modify files (e.g., formatting, linting auto-fix), stage and commit the changes: `git add -A && git commit --no-verify -m "💎 style: apply pre-commit hook fixes"` and push. If hooks fail with errors, launch **fixer** to address them, then re-run the hooks.

7. **Final review**: Launch the **reviewer** agent on the full PR diff (`git diff <base-branch>...HEAD`) to review the cumulative changes across all tasks. If issues are found, launch **fixer** to address them, commit, and push. After the final review passes, update the PR description to check off the **Review** task.

8. Report the PR URL to the user
    - If changes were stashed during worktree setup, remind the user to `git stash pop` in the main repo

Important:
- A single branch and PR are used for the entire sequence of tasks
- The PR is created upfront so reviewers can follow progress in real time
- After each task, changes are pushed and the PR description is updated to check off the completed task
- If a task fails, ask the user whether to continue with remaining tasks or stop
