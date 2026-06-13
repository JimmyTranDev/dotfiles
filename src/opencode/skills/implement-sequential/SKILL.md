---
name: implement-sequential
description: Sequential local implementation workflow — implement an ordered list of tasks one by one, committing after each, in the current working directory
---

## Pattern Overview

The sequential implementation workflow processes an ordered list of tasks one at a time in the current working directory — implementing, reviewing, fixing, and committing each task before moving to the next. No worktrees or PRs are created; all work stays local until explicitly pushed.

Use this pattern when tasks must be done in order, when each task's output is required by the next, or when you want isolated commits per task for clean history.

Distinct from the **pr-sequential** workflow in that it:
- Does not create a worktree (works in the current directory)
- Does not create a PR upfront
- Does not push after each task (push is opt-in at the end)
- Pre-commit hooks run once at the end, not after each task

## Setup

1. Parse the ordered task list from arguments (split on newlines, numbered lists, commas, or semicolons). Preserve the order.
2. If only one task is detected, suggest using `/implement` instead and stop.
3. Create a TodoWrite todo for each task (all set to `pending`).
4. Check if the current branch has an open PR:
   - Run `gh pr view --json number,body` to get the PR number and body
   - If a PR exists, update its body with `gh pr edit <pr-number> --body` to include a task checklist with all parsed tasks plus a final "Review" task, all unchecked
   - If no PR exists, skip PR description updates

## Per-Task Execution Loop

For each task N (starting at 1):

1. **Mark todo**: Set the current task to `in_progress`

2. **Implement**: Follow the `/implement` workflow for this task:
   - Load all applicable skills in parallel (always include **code-follower**, add others based on task type)
   - Implement the changes, delegating to specialized agents based on work type
   - Launch independent agents in parallel (e.g., **designer** + **tester**)

3. **Review**: Launch **reviewer** and **auditor** in parallel on `git diff HEAD` (unstaged + staged changes)

4. **Fix**: If issues found, launch **fixer** agents in parallel for independent fixes across different files. Run **reviewer** once more to verify (max 2 iterations).

5. **Commit** (skip pre-commit hooks during the loop — they run once at the end):
   - `git add -A`
   - `git commit --no-verify -m "<type>(<scope>): <description>"`

6. **Update PR description**: If a PR exists, check off the completed task in the checklist while preserving all descriptive summaries.

7. **Complete Todoist**: If the task description contains a Todoist URL (`app.todoist.com/...`), load **tool-todoist-cli** and complete it: `td task complete <url>`

8. **Mark todo**: Set to `completed` on success or `pending` on failure. If a task fails, ask the user whether to continue with remaining tasks or stop.

## Finalization

After all tasks are complete:

1. **Pre-commit hooks**: `git hook run pre-commit`. If hooks modify files, stage and commit: `git add -A && git commit --no-verify -m "style: apply pre-commit hook fixes"`. If hooks fail with errors, launch **fixer**, then re-run.

2. **Final review**: Launch **reviewer** on the full diff across all commits. If issues found, fix and commit. If a PR exists, check off the "Review" task in the PR description.

3. **Spec cleanup**: Follow the Spec Cleanup and Todoist Completion convention in AGENTS.md.

4. Report a summary: each task with its commit hash and status, total commits created.

## Key Rules

- Each task gets its own commit — do not batch multiple tasks into one commit
- Pre-commit hooks run **once at the end**, not after each task (skip with `--no-verify` during the loop)
- Skills loaded for one task can be reused for subsequent tasks if still applicable
- Do not push to remote unless the user explicitly asks
- All work happens in the current working directory (not in a worktree)
