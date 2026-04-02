---
name: merge-conflict
description: Resolve merge conflicts on the current branch by merging or rebasing the base branch
---

Usage: /merge-conflict [$ARGUMENTS]

Resolve merge conflicts on the current branch by merging the base branch and fixing all conflicted files.

$ARGUMENTS

Load the **git-workflows** and **git-conflict-resolution** skills for commit conventions, base branch strategy, and conflict resolution patterns.

1. Determine the base branch:
   - If `$ARGUMENTS` specifies a branch, use that
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
   - If a PR exists for the current branch, use its base branch: `gh pr view --json baseRefName -q .baseRefName`

2. Fetch and update (run in parallel):
   - `git fetch origin`
   - `git status --porcelain` to check for uncommitted changes

3. If there are uncommitted changes:
   - Stash them with `git stash push -m "merge-conflict-stash"`

4. Attempt the merge:
   - Run `git merge origin/<base-branch>`
   - If no conflicts, the merge completes automatically — skip to step 7

5. Resolve conflicts:
   - Run `git diff --name-only --diff-filter=U` to list all conflicted files
   - For each conflicted file:
     - Read the file to see the conflict markers
     - Analyze both sides (`ours` and `theirs`) to understand the intent of each change
     - Resolve by combining both changes where possible, or choosing the correct side when they are mutually exclusive
     - Stage the resolved file with `git add <file>`
   - After all files are resolved, commit with `git commit -m "🔨 refactor: resolve merge conflicts with <base-branch>"`

6. Verify the resolution:
   - Run `git diff <base-branch>...HEAD` to review the full diff
   - Run build, lint, or test commands if available to confirm the resolution is correct
   - If verification fails, use **fixer** to address issues and commit the fix

7. Push the changes:
   - `git push`
   - If the push fails due to remote changes, `git pull --rebase` and retry once

8. If changes were stashed in step 3:
   - Run `git stash pop` and notify the user if there are stash conflicts

9. Report a summary:
   - List of conflicted files and how each was resolved
   - Commit(s) created
   - Whether build/lint/test passed after resolution

Important:
- Do not force push unless the user explicitly requests it
- If a conflict is too ambiguous to resolve automatically (e.g., both sides rewrote the same logic differently), present both versions to the user and ask which to keep
- Never silently drop changes from either side
