---
name: implement-parallel
description: Implement multiple changes in parallel in the current working directory, committing all results together
---

Usage: /implement-parallel <list of changes to implement>

Implement multiple changes simultaneously by launching independent agents in parallel, then merge all results into a single verified commit in the current working directory.

$ARGUMENTS

Load the **git-workflows** and **meta-parallelization** skills.

1. Parse the task list from `$ARGUMENTS`:
   - Split the input into individual change descriptions (separated by newlines, numbered lists, commas, or semicolons)
   - Each item is a discrete unit of work
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

4. **Detect task dependencies**: Analyze all tasks for file overlap. If two tasks are likely to touch the same file(s), mark the lower-priority one as dependent on the first. Dependencies are sequenced after the independent batch completes. Present the dependency graph to the user and confirm before proceeding.

5. Launch all independent tasks in parallel — one **general** or **implementer** agent per task. These agents should NOT wait for each other and should NOT execute sequentially:
   - Use the Task tool to dispatch all independent agents in a SINGLE message
   - Each agent receives its specific task description and the full context of the task list

   For each task, the agent:
   a. **Mark todo**: Set the task to `in_progress`
   b. **Implement**: Follow the `/implement` command workflow for this task:
      - Load all applicable skills in parallel (always include **code-follower**, add others based on task type — see `/implement` for the full skill list)
      - Implement the changes, delegating to specialized agents based on work type
      - Launch independent sub-agents in parallel (e.g., **designer** + **tester**)
   c. **Mark todo**: Set the task to `completed` on success or `pending` on failure
   d. **Report back**: Return the task description, a one-line summary of changes, list of modified files, commit-ready status, and success/failure

   Agents work independently on their assigned task. A failure in one task does not block others.

6. **Implement dependent tasks sequentially** (if any): After all independent tasks complete, process each dependent task using the same agent workflow. These run in order since they depend on the independent tasks' output.

7. Collect results from all agents. If all tasks failed, report the failures and stop.

8. **Commit combined changes**: Stage and commit all changes together using the format from the **git-workflows** skill:
   - `git add -A`
   - `git commit -m "<type>(<scope>): <summary description covering all changes>"`

9. **Review cycle**: Launch **reviewer**, **auditor**, and **tester** agents in parallel on the combined diff. If issues are found, launch **fixer** agents in parallel for independent fixes across different files. Stage and commit fixes: `git add -A && git commit -m "fix: address review and audit findings"`. Run **reviewer** once more to verify (max 2 iterations).

10. **Update PR description**: If a PR exists, use `gh pr edit <pr-number> --body` to check off all completed tasks while preserving descriptive summaries. Also check off the **Review** task.

11. **Complete Todoist tasks**: If any task description contains a Todoist URL (`app.todoist.com/...`), load the **tool-todoist-cli** skill and complete those tasks: `td task complete <url>` for each URL.

12. Report outcome to the user:
    - Table showing each task, status (completed/failed/skipped), modified files, and any notes
    - Count of tasks completed vs failed vs skipped
    - Commit hash for the combined commit

Important:
- All work happens in the current working directory
- Independent tasks are dispatched in parallel — maximize fan-out
- Dependent tasks run sequentially after their prerequisites complete
- Always use braces for all `if`/`else`/`for`/`while` statements
- Do not push to remote unless the user explicitly asks
- **Spec cleanup**: If `$ARGUMENTS` references files in `plans/` (paths starting with `plans/` or containing `.md` files inside `plans/`), ask the user for confirmation before deleting each consumed spec file after all its tasks are successfully implemented and committed. If confirmed and the file is tracked by git, use `git rm`; otherwise use `rm`. If the `plans/` directory is empty after deletion, remove it too. Note in the final summary: "Removed consumed spec: plans/xyz.md"
