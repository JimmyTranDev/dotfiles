---
description: Resolve conflict markers in all conflicted files
---

Usage: /fix-conflict

Resolve conflict markers in files that are currently in a conflicted state — for use when mid-merge, mid-rebase, or mid-cherry-pick.

Load the **git-conflict-resolution** and **code-follower** skills in parallel.

1. Identify conflicted files:
   - Run `git diff --name-only --diff-filter=U` to list all files with unresolved conflicts
   - Run `git status` to identify the operation in progress (merge, rebase, or cherry-pick)
   - If no files are conflicted, notify the user and stop

2. For each conflicted file:
   - Read the file to see all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
   - Analyze both sides (`ours` and `theirs`) to understand the intent of each change
   - Resolve by combining both changes where possible, or choosing the correct side when they are mutually exclusive
   - If a conflict is too ambiguous (both sides rewrote the same logic differently), present both versions to the user and ask which to keep
   - Stage the resolved file with `git add <file>`

3. Verify the resolution:
   - Run `git diff --cached` to review the staged resolution
   - Run `lint-check.sh` to confirm the resolution is correct
   - If verification fails, use **fixer** to address issues

4. Auto-continue the operation:
   - Only proceed if verification (lint) passed. If verification failed, stop and ask the user to decide.
   - Detect the operation type from `git status`:
     - If merge: run `git commit --no-edit`
     - If rebase: run `git rebase --continue`
     - If cherry-pick: run `git cherry-pick --continue`
   - If the continue triggers new conflicts, loop back to step 2 (resolve the new conflicts)
   - Keep looping until no more conflicts remain or a non-conflict error occurs
   - If a non-conflict error occurs, report the error and offer to abort the operation (`git rebase --abort`, `git merge --abort`, or `git cherry-pick --abort`)

5. Report a summary:
   - List of conflicted files and how each was resolved
   - Whether build/lint passed after resolution
   - Whether the operation was completed successfully or stopped due to an error
   - Total number of conflict rounds resolved (for rebase)

Important:
- Never silently drop changes from either side
- Do not run `git merge`, `git rebase`, or `git cherry-pick` — this command only resolves existing conflicts and continues in-progress operations
- Only auto-continue if verification passes — if lint/tests fail, stop and ask the user
