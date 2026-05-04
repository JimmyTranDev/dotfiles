---
name: scaffold
description: Generate boilerplate for common patterns like components, hooks, services, and tests
---

Usage: /scaffold [type] [name]

Generate boilerplate files for a specified pattern, matching the existing codebase conventions exactly.

$ARGUMENTS

1. Load the **code-follower** skill
2. Parse the type and name from arguments
3. If type is not provided or is ambiguous, ask the user to clarify using one of: component, hook, service, test, page, api-route
4. If name is not provided, notify the user and stop
5. Find existing examples of the specified type in the codebase:
   - component: look for existing components and their file structure
   - hook: look for existing custom hooks
   - service: look for existing service modules
   - test: look for existing test files and their patterns
   - page: look for existing page/route files
   - api-route: look for existing API route handlers
6. If no existing examples of the type are found, notify the user that the pattern doesn't exist in this codebase and ask how to proceed
7. Analyze the existing examples for:
   - File naming convention (kebab-case, PascalCase, etc.)
   - Directory placement
   - Import patterns
   - Export patterns
   - Internal structure (types, constants, main logic)
8. Generate the new file(s) following the exact same conventions
9. If the type includes a test file by convention, generate that too
10. Report what files were created and where

Constraints:
- Never invent new conventions — only replicate what already exists
- If the codebase has no examples of the requested type, do not guess — ask the user
- Place files in the correct directory based on existing project structure
