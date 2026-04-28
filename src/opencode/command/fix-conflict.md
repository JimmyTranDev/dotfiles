---
name: fix-conflict
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
   - Run build, lint, or test commands if available to confirm the resolution is correct
   - If verification fails, use **fixer** to address issues

4. Do NOT commit or continue the merge/rebase automatically:
   - Notify the user that conflicts are resolved and staged
   - Tell them to run `git commit` (for merge) or `git rebase --continue` (for rebase) when ready

5. Report a summary:
   - List of conflicted files and how each was resolved
   - Whether build/lint/test passed after resolution
   - What command the user should run next to complete the operation

## Skill Improvement

After completing the work, load the **meta-skill-learnings** skill and improve any relevant skills with reusable patterns, gotchas, or anti-patterns discovered during investigation.

Important:
- Never silently drop changes from either side
- Do not run `git merge`, `git rebase`, or `git cherry-pick` — this command only resolves existing conflicts
- Do not commit or continue the operation — leave that to the user
