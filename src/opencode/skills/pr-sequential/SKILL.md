---
name: pr-sequential
description: Sequential PR workflow — create worktree and PR upfront, then implement tasks one by one with commit and push after each
---

## Pattern Overview

The sequential PR workflow creates a **single worktree and PR before any implementation begins**, then works through tasks one by one — committing, pushing, and updating the PR checklist after each completed task. Reviewers can follow progress in real time.

Use this pattern when tasks must be done in order, when each task's output affects the next, or when visibility into incremental progress is important.

## Setup

1. Parse the task list from arguments (split on newlines, numbered lists, commas, or semicolons)
2. If only one task is detected, suggest using `/pr` instead and stop
3. Run `git-branch-info.sh` and use the `base_branch` value
4. Derive a kebab-case branch name from the overall goal
5. Check for uncommitted changes: `git status --porcelain` and `git diff --cached --stat` (in parallel)
6. If staged or unstaged changes exist, stash them: `git stash push -m "<branch-name>"`
7. Create the worktree: `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`
8. If changes were stashed, apply in the worktree: `git stash pop`

## PR Creation (Before Any Implementation)

1. Create an initial empty commit in the worktree:
   `git commit --allow-empty --no-verify -m "chore: initialize <branch-name>"`
2. Push: `git push -u origin <branch-name>`
3. Create the PR with `gh pr create` targeting the base branch:
   - Title: concise overall goal
   - Body: checklist of all tasks with unchecked boxes, each with a descriptive summary. End with a final "Review" task:
     ```
     ## Tasks
     - [ ] **Task title** — What changes, which files or areas, expected outcome.
     - [ ] **Review** — Final review of all cumulative changes across the full PR diff.
     ```

## Per-Task Execution Loop

For each task N (starting at 1):

1. **Implement**: Apply changes in the worktree (`~/Programming/wcreated/<branch-name>/`). Load all applicable skills in parallel. Delegate to specialized agents based on work type.

2. **Review**: Launch **reviewer** and **auditor** in parallel on `git diff HEAD~1...HEAD`

3. **Fix**: If issues found, launch **fixer** agents in parallel for independent fixes across different files. Commit fixes: `git add -A && git commit --no-verify -m "fix: address review and audit findings"`. Run **reviewer** once more to verify (max 2 iterations).

4. **Commit and push**:
   - `git add -A`
   - `git commit --no-verify -m "<type>(<scope>): <description>"`
   - `git push`

5. **Update PR description**: `gh pr edit <pr-number> --body` — check off the completed task in the checklist, preserving all descriptive summaries and the remaining unchecked tasks.

6. **Complete Todoist**: If the task description contains a Todoist URL (`app.todoist.com/...`), complete it: `td task complete <url>`

## Finalization

After all tasks are complete:

1. **Pre-commit hooks**: `git hook run pre-commit`. If hooks modify files, stage and commit: `git add -A && git commit --no-verify -m "style: apply pre-commit hook fixes"` and push. If hooks fail with errors, launch **fixer**, then re-run.

2. **Final review**: Launch **reviewer** on the full PR diff (`git diff <base-branch>...HEAD`). If issues found, fix, commit, and push.

3. **Update PR**: Check off the "Review" task in the PR description.

4. **Spec cleanup**: Follow the Spec Cleanup and Todoist Completion convention in AGENTS.md.

5. Report the PR URL to the user. If changes were stashed, remind the user to `git stash pop` in the main repo.

## Key Rules

- One worktree, one PR, many commits — do not create multiple PRs
- All work happens in `~/Programming/wcreated/<branch-name>/`, never in the main repo
- Each task gets its own commit — do not batch multiple tasks into one commit
- Push after every task so reviewers see real-time progress
- If a task fails, ask the user whether to continue with remaining tasks or stop
- If a stash pop has conflicts, notify the user and stop
- Pre-commit hooks run **once at the end**, not after each task (skip with `--no-verify` during the loop)
