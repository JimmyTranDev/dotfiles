---
name: fix-checks
description: Run tests, type checking, and linting then fix all failures
---

Usage: /fix-checks [scope]

Run all code quality checks (tests, type checking, linting) and automatically fix any issues found.

$ARGUMENTS

1. Detect the project's tech stack:
   - Look for `package.json`, `tsconfig.json`, `pom.xml`, `build.gradle`, `build.gradle.kts` in the workspace root
   - Determine available check commands from package.json scripts, Makefile targets, or build tool conventions

2. Run all checks in parallel (use parallel tool calls — these have no dependencies between them):
   - **Tests**: `npm test` / `pnpm test` / `yarn test` / `mvn test` / `gradle test` (whatever is configured)
   - **Type checking**: `npx tsc --noEmit` / `pnpm tsc --noEmit` (for TypeScript projects)
   - **Linting**: `npm run lint` / `pnpm lint` / `npx eslint .` (for JS/TS projects)
   - Run all three as parallel Bash tool calls in a single message — do NOT run them sequentially
   - If a script is not available, skip that check and note it

3. Collect failures:
   - Parse each check's output for errors, failures, and warnings
   - Group issues by category: test failures, type errors, lint errors
   - Prioritize: test failures first, then type errors, then lint errors

4. Fix issues iteratively:
   - For each category (in priority order), fix all issues
   - **Test failures**: Investigate root cause — fix the source code, not the test (unless the test itself is wrong)
   - **Type errors**: Fix type mismatches, missing types, incorrect generics
   - **Lint errors**: Apply auto-fix first (`eslint --fix`), then manually fix remaining issues
   - After fixing each category, re-run that check to confirm it passes before moving to the next

5. Final verification:
   - Re-run all three checks as parallel Bash tool calls in a single message
   - If any check still fails, repeat the fix cycle (max 3 iterations)
   - Report final status: which checks pass, which still fail (if any)

6. Load applicable skills (load all in a single parallel batch at the start, before running checks):
   - **code-follower**: Always load to match existing codebase conventions
   - **code-conventions**: Load for TypeScript/JavaScript projects
   - **tool-eslint-config**: Load when dealing with ESLint configuration issues

Delegate to agents:
- **fixer**: For each failing test or complex type error that requires investigation
- **tester**: After fixes are applied, to verify test coverage is maintained

Report a summary: total issues found per category, issues fixed, and final check status.
