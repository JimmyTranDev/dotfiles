---
name: pr-parallel
description: Parallel worktree PR workflow — implement each task in its own worktree simultaneously, merge into an integration worktree, and create one PR
---

## Pattern Overview

The parallel worktree workflow gives each task its own isolated worktree and agent, running all implementations simultaneously. When tasks complete, their branches are merged sequentially into a single integration worktree to resolve conflicts. One PR is created with the combined result.

Use this pattern when tasks are independent (they don't depend on each other's output) and can safely be implemented simultaneously without file conflicts.

## Branch Naming

- **Integration branch**: kebab-case summarizing the overall goal (e.g., `feat-user-settings-overhaul`)
- **Task branches**: prefixed with the integration branch name + `--` + a short task suffix (e.g., `feat-user-settings-overhaul--add-theme-picker`, `feat-user-settings-overhaul--fix-email-validation`)

## Setup

1. Parse the task list from arguments (split on newlines, numbered lists, commas, or semicolons)
2. If only one task is detected, suggest using `/pr` instead and stop
3. Follow the shared **Worktree Setup** from the AGENTS.md `pr-*` command conventions for base-branch detection (`git-branch-info.sh`), the uncommitted-changes check, and stashing (`git stash push -m "pr-parallel-stash"`)
4. Derive the integration branch name and one task branch name per task
5. Create the **integration worktree**: `git worktree add ~/Programming/wcreated/<integration-branch> -b <integration-branch>`
6. Create all **task worktrees** in parallel: `git worktree add ~/Programming/wcreated/<task-branch> -b <task-branch>` (one per task — if any creation fails, report the error for that task and continue)

## Parallel Task Implementation

Launch a separate **general** agent for each task in a single message (fully parallel). Each agent works exclusively in its own worktree:

1. **Implement**: Apply changes in `~/Programming/wcreated/<task-branch>/`. Load all applicable skills in parallel. Delegate to specialized agents based on work type.

2. **Review**: Launch **reviewer** and **auditor** in parallel on `git diff <base-branch>...HEAD`

3. **Fix**: If issues found, launch **fixer** agents in parallel, commit fixes, run **reviewer** once more to verify (max 2 iterations).

4. **Commit**: 
   - `git add -A`
   - `git commit --no-verify -m "<type>(<scope>): <description>"`

5. **Merge into integration** (sequential lock — one at a time):
   - Acquire sequential access on the integration worktree (`~/Programming/wcreated/<integration-branch>/`)
   - Run: `git merge <task-branch> --no-ff -m "chore: merge <task-branch>"`
   - If merge has conflicts, resolve using the **git-conflict-resolution** skill — combine both changes where possible, ask the user when ambiguous, never silently drop code
   - If merge is catastrophically broken, abort with `git merge --abort`, skip this task, and report it
   - After successful merge, run a quick build/lint check if available to catch early integration issues
   - Release the lock so the next completed task can merge

6. **Report**: Return task branch name, commit count, one-line summary, merge status, and success/failure

A failure in one task does not block the others.

## Finalization

After all parallel agents complete:

1. **Collect results**: If all tasks failed, report failures and stop.

2. **Integration review**: Launch **reviewer** and **auditor** in parallel on the full combined diff (`git diff <base-branch>...HEAD`) in the integration worktree. If issues found, fix and commit.

3. **Pre-commit hooks**: `git hook run pre-commit` in the integration worktree. If hooks modify files, stage and commit: `git add -A && git commit --no-verify -m "style: apply pre-commit hook fixes"`. If hooks fail, launch **fixer**, then re-run.

4. **Push**: `git push -u origin <integration-branch>`

5. **Create PR**: `gh pr create` targeting the base branch:
   - Title: concise overall goal
   - Body: summary section + checklist showing each task's status (checked if merged, unchecked with note if skipped). Include task branch names as references.

6. **Spec cleanup**: Follow the Spec Cleanup and Todoist Completion convention in AGENTS.md.

7. Report: PR URL, table of each task (branch, merge status, conflict summary), counts of merged/skipped/failed. If changes were stashed, remind the user to `git stash pop` in the main repo.

## Key Rules

- Task implementation is fully parallel — each task gets its own worktree and agent
- Merges into the integration worktree happen **sequentially** to allow orderly conflict resolution
- A failure in one task does not block others — failed tasks are skipped during integration
- If a merge conflict cannot be resolved, skip that task branch and report — the PR proceeds with remaining tasks
- Never silently drop code from either side during conflict resolution
- All task work happens in task worktrees; all merge work happens in the integration worktree
- If a stash pop has conflicts, notify the user and stop
