---
name: implement-sequential
description: Implement an ordered list of changes sequentially, committing after each completed task
---

Usage: /implement-sequential <ordered list of changes to implement>

Implement an ordered list of changes sequentially in the current working directory, committing after each completed task.

$ARGUMENTS

Load the **git-workflows** skill.

1. Parse the ordered task list from `$ARGUMENTS`:
   - Split the input into individual change descriptions (separated by newlines, numbered lists, commas, or semicolons)
   - Preserve the order — tasks are implemented sequentially
   - If only one item is detected, notify the user and suggest using `/implement` instead, then stop

2. Create a TodoWrite todo for each task (all set to `pending`)

3. Check if the current branch has an open PR:
   - Run `gh pr view --json number,body` to get the PR number and body
   - If a PR exists, update its body with `gh pr edit <pr-number> --body` to include a task checklist with all parsed tasks plus a final **Review** task, all unchecked. Example:
     ```
     ## Tasks
     - [ ] **Add user settings page** — Create a new `/settings` route with form fields for display name, email preferences, and theme selection.
     - [ ] **Fix session timeout redirect** — Add proper redirect with a return URL parameter.
     - [ ] **Review** — Final review of all cumulative changes.
     ```
   - If no PR exists, skip PR description updates

4. Process each task sequentially — for task N (starting at 1):

   a. **Mark todo**: Set the current task to `in_progress`

   b. **Implement**: Follow the `/implement` command workflow for this task:
      - Load all applicable skills in parallel (always include **follower**, add others based on task type — see `/implement` for the full skill list)
      - Implement the changes, delegating to specialized agents based on work type
      - Launch independent agents in parallel (e.g., **designer** + **tester**, **reviewer** + **auditor**)

   c. **Review**: Launch **reviewer**, **auditor**, and **tester** agents in parallel on the diff from `git diff HEAD` (unstaged + staged changes)

   d. **Fix**: If issues were found, launch **fixer** agents in parallel for independent fixes across different files. Run **reviewer** once more to verify (max 2 iterations).

    e. **Commit**: Stage and commit using the format from the **git-workflows** skill (skip hooks during sequential tasks — they run once at the end):
       - `git add -A`
       - `git commit --no-verify -m "<emoji> <type>(<scope>): <description>"`

   f. **Update PR description**: If a PR exists, use `gh pr edit <pr-number> --body` to check off the completed task while preserving all descriptive summaries

   g. **Complete Todoist task**: If the task description contains a Todoist URL (`app.todoist.com/...`), load the **todoist-cli** skill and complete the task: `td task complete <url>`

   h. **Mark todo**: Set the current task to `completed` on success or `pending` on failure

5. **Run pre-commit hooks**: Run `git hook run pre-commit` to execute all pre-commit hooks against the current state. If the hooks modify files (e.g., formatting, linting auto-fix), stage and commit the changes: `git add -A && git commit --no-verify -m "💎 style: apply pre-commit hook fixes"`. If hooks fail with errors, launch **fixer** to address them, then re-run the hooks.

6. **Final review**: Launch the **reviewer** agent on the full diff across all commits. If issues are found, launch **fixer** to address them and commit. If a PR exists, update the PR description to check off the **Review** task.

7. After all tasks are complete, report a summary:
   - List each task with its commit hash and status (completed/failed)
   - Total commits created

Important:
- All work happens in the current working directory
- Each task gets its own commit — do not batch multiple tasks into one commit
- Skills loaded for one task can be reused for subsequent tasks if still applicable
- If a task fails, ask the user whether to continue with remaining tasks or stop
- Do not push to remote unless the user explicitly asks
