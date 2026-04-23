---
name: specify-conflict
description: Analyze conflict markers in conflicted files and report resolution strategies without making changes and write spec to `spec/conflict/`
---

Usage: /specify-conflict [files or description]

Analyze conflict markers in files that are currently in a conflicted state and report resolution strategies without applying any changes. Write all findings to a spec file.

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
   - Determine the recommended resolution: combine both changes, choose one side, or flag as ambiguous

3. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - For each conflicted file, include:
     - File path and number of conflict regions
     - For each conflict: both sides with context, analysis of intent, and recommended resolution strategy
     - Whether the conflict is straightforward (mechanical merge) or ambiguous (requires human judgment)
   - Flag any conflicts where both sides rewrote the same logic differently as requiring manual review

4. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Verify conflict analysis and resolution recommendations are accurate

5. Write findings to a spec file:
   - Create the `spec/conflict/` directory if it doesn't exist
   - Choose the filename: use the branch name in kebab-case (e.g., `feature-auth.md`); if a file with that name already exists, append a timestamp suffix
   - Write all findings to the file: list of conflicted files, each conflict region with both sides, intent analysis, recommended resolution, and confidence level (straightforward/ambiguous)
   - Print a brief summary to chat: the spec file path, total conflicted files, total conflict regions, and how many are ambiguous
