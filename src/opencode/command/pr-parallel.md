---
name: pr-parallel
description: Implement tasks in parallel worktrees, merge all into an integration worktree resolving conflicts, and create a single PR
---

Usage: /pr-parallel <list of changes to implement>

Implement each task in its own parallel worktree, then merge all completed branches into a single integration worktree — resolving conflicts as they arise — and create one pull request containing the combined result.

$ARGUMENTS

Load the **worktree-workflow**, **git-workflows**, **git-conflict-resolution**, and **todoist-cli** skills in parallel.

1. Parse the task list from `$ARGUMENTS`:
   - Split the input into individual change descriptions (separated by newlines, numbered lists, commas, or semicolons)
   - Each item is a discrete unit of work
   - If only one item is detected, notify the user and suggest using `/pr` instead, then stop

2. Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

3. Derive branch names:
   - **Integration branch**: a kebab-case name summarizing the overall goal (e.g., `feat-user-settings-overhaul`)
   - **Task branches**: one per task, prefixed with the integration branch name and a short task suffix (e.g., `feat-user-settings-overhaul--add-theme-picker`, `feat-user-settings-overhaul--fix-email-validation`). Use `--` as the separator between integration prefix and task suffix.

4. Check for uncommitted changes (run in parallel):
   - `git status --porcelain`
   - `git diff --cached --stat`

5. If there are staged or unstaged changes:
   - Stash them with `git stash push -m "pr-parallel-stash"`

6. Create the integration worktree from the base branch:
   - `git worktree add ~/Programming/wcreated/<integration-branch> -b <integration-branch>`

7. Create all task worktrees in parallel (one per task):
   - For each task: `git worktree add ~/Programming/wcreated/<task-branch> -b <task-branch>`
   - If any worktree creation fails, report the error for that task and continue with the rest

8. Implement all tasks in parallel — launch a separate **general** agent for each task. Each agent works exclusively in its own worktree directory (`~/Programming/wcreated/<task-branch>/`):

   a. **Implement**: Apply the changes, stage, and commit:
      - `git add -A`
      - `git commit --no-verify -m "<type>(<scope>): <emoji> <description>"`
      - Multiple commits are fine if the task warrants it
      - Use the commit type/emoji mapping:

        | Key | Type | Emoji |
        |-----|------|-------|
        | `f` | `feat` | `✨` |
        | `F` | `fix` | `🐛` |
        | `c` | `chore` | `🔧` |
        | `r` | `refactor` | `🔨` |
        | `d` | `docs` | `📚` |
        | `s` | `style` | `💎` |
        | `t` | `test` | `🧪` |
        | `p` | `perf` | `🚀` |
        | `b` | `build` | `📦` |
        | `a` | `ci` | `👷` |
        | `R` | `revert` | `⏪` |

   b. **Review**: Launch **reviewer** and **auditor** agents in parallel on the diff from `git diff <base-branch>...HEAD`:
      - **reviewer**: catches bugs, design issues, and code quality problems
      - **auditor**: scans for security vulnerabilities and exploitable patterns

   c. **Fix**: If issues were found, launch **fixer** to address them, then stage and commit: `git add -A && git commit --no-verify -m "fix: 🐛 address review and audit findings"`. Run **reviewer** once more to verify (max 2 iterations).

   d. **Push**: Push the task branch with `git push -u origin <task-branch>`

   e. **Report back**: Return the task branch name, commit count, a one-line summary of what was done, and success/failure status

   Each agent works exclusively in its own worktree. A failure in one task does not block others — all tasks run to completion independently.

9. Collect results from all parallel agents. If all tasks failed, report the failures, clean up, and stop.

10. Merge completed task branches into the integration worktree sequentially. Work in `~/Programming/wcreated/<integration-branch>/`:

    For each successful task branch (in the order the tasks were originally listed):
    a. Run `git merge <task-branch> --no-ff -m "chore: 🔧 merge <task-branch>"`
    b. If the merge has conflicts:
       - Run `git diff --name-only --diff-filter=U` to list conflicted files
       - For each conflicted file, read both sides and the ancestor using the **git-conflict-resolution** skill's decision tree
       - Resolve conflicts by combining both changes where possible, or choosing the correct side when mutually exclusive
       - If a conflict is too ambiguous (both sides rewrote the same logic differently with no clear correct answer), present both versions to the user and ask which to keep — never silently drop code
       - Stage resolved files: `git add <file>`
       - Complete the merge: `git commit --no-verify -m "chore: 🔧 merge <task-branch> (resolved conflicts)"`
    c. After each merge, run a quick build/lint check if available to catch integration issues early
    d. If a merge is catastrophically broken (cannot be resolved), abort with `git merge --abort`, skip that task branch, and continue with the remaining branches. Report the skipped task.

11. Final review on the integration worktree — launch **reviewer**, **auditor**, and **tester** agents in parallel on the full combined diff (`git diff <base-branch>...HEAD`):
    - **reviewer**: catches integration issues across the combined changes
    - **auditor**: scans the combined result for security vulnerabilities
    - **tester**: verifies test coverage and adds missing tests for the combined changes

12. If issues were found:
    - Launch **fixer** to address them in the integration worktree
    - Stage and commit: `git add -A && git commit --no-verify -m "fix: 🐛 address integration review findings"`
    - Run **reviewer** once more to verify (max 2 iterations)

13. Run pre-commit hooks: `git hook run pre-commit` in the integration worktree. If hooks modify files, stage and commit: `git add -A && git commit --no-verify -m "style: 💎 apply pre-commit hook fixes"`. If hooks fail with errors, launch **fixer** to address them, then re-run.

14. Push the integration branch:
    - `git push -u origin <integration-branch>`

15. Create the PR with `gh pr create` targeting the base branch:
    - Title: a concise summary of the overall goal
    - Body: a summary section, followed by a checklist of all tasks with their status (checked if merged successfully, unchecked with a note if skipped due to conflicts). Include the task branch names as references.

16. Complete Todoist tasks: for each successfully merged task that contains a Todoist URL (`app.todoist.com/...`), complete it: `td task complete <url>`

17. Report outcome to the user:
    - PR URL
    - Table showing each task, its task branch, merge status (merged / skipped / failed), and conflict summary if any
    - Count of tasks merged vs skipped vs failed
    - If changes were stashed in step 5, remind the user to `git stash pop` in the main repo

Important:
- All work happens in worktree directories, never in the main repo
- Task implementation is fully parallel — each task gets its own worktree and agent
- The integration worktree is the single point where all parallel work converges
- Merges into the integration worktree happen sequentially to allow orderly conflict resolution
- A failure in one task does not block others — failed tasks are skipped during integration
- If a merge conflict cannot be resolved, that task branch is skipped and reported — the PR proceeds with the remaining tasks
- Never silently drop code from either side during conflict resolution
- Do not modify the main repo's working tree
- Task branches are pushed individually so their history is preserved and referenceable in the PR
