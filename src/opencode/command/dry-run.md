---
name: dry-run
description: Validate an implementation plan showing what would change without making modifications
---

Usage: /dry-run $ARGUMENTS

$ARGUMENTS

Analyze the requested changes and show exactly what would be created, modified, or deleted — without actually making any changes.

## Workflow

1. Parse `$ARGUMENTS`:
   - If a spec file path → read and analyze the spec
   - If a feature description → plan the implementation
   - If a command reference (e.g., "run /implement X") → simulate that command

2. For each change that would be made, report:
   - **File path**: exact path of file to create/modify/delete
   - **Action**: create / modify / delete
   - **Description**: what would change in 1-2 sentences
   - **Risk level**: low (safe, reversible) / medium (modifies existing logic) / high (breaking change potential)

3. Present as a structured report:

   ```
   ## Dry Run: <description>
   
   ### Files to Create (N)
   | File | Purpose | Risk |
   |------|---------|------|
   | path/to/new.ts | New service for X | low |
   
   ### Files to Modify (N)
   | File | Change | Risk |
   |------|--------|------|
   | path/to/existing.ts | Add method Y | medium |
   
   ### Files to Delete (N)
   | File | Reason | Risk |
   |------|--------|------|
   
   ### Dependencies
   - Packages to install: [list]
   - Config changes needed: [list]
   
   ### Estimated Scope
   - Lines of code: ~N
   - Files affected: N
   - Complexity: low/medium/high
   ```

4. After presenting, ask: "Proceed with implementation?"

## Rules

- Do NOT make any file changes, git operations, or installations
- Be specific about paths — don't use placeholders like "some file"
- Flag potential breaking changes prominently
- If the plan seems overly complex, suggest simpler alternatives
