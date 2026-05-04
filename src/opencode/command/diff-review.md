---
name: diff-review
description: Review only the current git diff for bugs, issues, and improvements
---

Usage: /diff-review [staged|unstaged|both]

Review the current git diff for bugs, logical errors, and improvement opportunities without reviewing the full codebase.

$ARGUMENTS

1. Load the **code-follower**, **code-logic-checker**, and **code-soundness** skills
2. Determine the diff scope:
   - `staged`: run `git diff --cached`
   - `unstaged`: run `git diff`
   - `both` (default): run both commands
3. If the diff is empty, notify the user that there are no changes to review and stop
4. Collect the full diff output
5. Delegate to the **reviewer** agent with the diff content and instructions to focus on:
   - Bugs and logical errors
   - Missing error handling
   - Type safety issues
   - Convention violations relative to surrounding code
   - Security concerns in the changed lines
6. Output findings with inline references in the format `file:line — issue description`
7. Categorize findings by severity: critical, warning, suggestion
8. If no issues are found, confirm the diff looks clean

Constraints:
- Do not modify any files — this is review only
- Focus only on the changed lines and their immediate context
- Do not review unchanged code that happens to be in the same file
- Write findings to `plans/` only if the user requests a spec — otherwise output to chat
