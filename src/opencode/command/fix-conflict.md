---
name: fix-conflict
description: Resolve conflict markers in files that are currently in a conflicted state
---

Usage: /fix-conflict [files or description]

Resolve conflict markers in files that are already in a conflicted state — for use when you are mid-merge, mid-rebase, or mid-cherry-pick.

$ARGUMENTS

Load the **git-conflict-resolution** skill for conflict resolution patterns and strategies.

1. Identify conflicted files:
   - Run `git diff --name-only --diff-filter=U` to list all files with unresolved conflicts
   - If the user specifies files, focus on those — warn if any are not actually conflicted
   - If no files are conflicted, notify the user and stop

2. For each conflicted file:
   - Read the file to see all conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
   - Identify the merge operation in progress (`git status` shows merge, rebase, or cherry-pick)
   - Analyze both sides (`ours` and `theirs`) to understand the intent of each change
   - Resolve by combining both changes where possible, or choosing the correct side when they are mutually exclusive
   - If a conflict is too ambiguous (both sides rewrote the same logic differently), present both versions to the user and ask which to keep
   - Stage the resolved file with `git add <file>`

3. Verify the resolution:
   - Run `git diff --cached` to review the staged resolution
   - Run build, lint, or test commands if available to confirm the resolution is correct
   - If verification fails, use **fixer** to address issues

4. Do NOT commit or continue the merge/rebase automatically:
   - Notify the user that conflicts are resolved and staged
   - Tell them to run `git commit` (for merge) or `git rebase --continue` (for rebase) when ready

5. Report a summary:
   - List of conflicted files and how each was resolved
   - Whether build/lint/test passed after resolution
   - What command the user should run next to complete the operation

Important:
- Never silently drop changes from either side
- Do not run `git merge`, `git rebase`, or `git cherry-pick` — this command only resolves existing conflicts
- Do not commit or continue the operation — leave that to the user
