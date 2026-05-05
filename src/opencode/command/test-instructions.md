---
name: test-instructions
description: Generate manual testing instructions for QA from the current diff or spec
---

Usage: /test-instructions [diff, branch, PR URL, or spec file]

$ARGUMENTS

Generate comprehensive manual testing instructions for QA engineers based on the changes in a diff, branch, or spec file.

## Workflow

1. Determine the source:
   - If `$ARGUMENTS` is a PR URL → fetch diff via `gh pr diff`
   - If `$ARGUMENTS` is a branch name → diff against base branch
   - If `$ARGUMENTS` is a file path to a spec → read the spec
   - If no arguments → use current branch diff against base branch

2. Analyze the changes to identify:
   - New features or UI elements added
   - Modified behaviors
   - Edge cases that need manual verification
   - Integration points with other systems
   - Data flows that should be validated

3. Generate testing instructions with this structure:

   ```
   # Testing Instructions: <feature name>
   
   ## Prerequisites
   - Environment setup steps
   - Test data requirements
   - Required permissions/accounts
   
   ## Test Scenarios
   
   ### Scenario 1: <happy path>
   1. Step-by-step instructions
   2. Expected result at each step
   3. What to verify
   
   ### Scenario 2: <edge case>
   ...
   
   ## Regression Checks
   - Related features that might be affected
   - Quick smoke tests for adjacent functionality
   
   ## Not In Scope
   - What doesn't need testing for this change
   ```

4. Copy to clipboard if possible (macOS: `pbcopy`)

## Rules

- Instructions must be understandable by someone unfamiliar with the codebase
- Include specific test data values, not "enter some data"
- Each step should have a clear expected result
- Group by user flow, not by file changed
