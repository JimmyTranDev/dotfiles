---
name: check
description: Run lint, test, build, and typecheck in parallel and report combined results
---

Usage: /check [specific checks]

$ARGUMENTS

Run project quality checks (lint, test, build, typecheck) in parallel and report combined results.

## Workflow

1. Auto-detect available checks from the project:
   - Look for `package.json` scripts: `lint`, `test`, `build`, `typecheck`/`tsc`/`type-check`
   - Look for `Makefile` targets: `lint`, `test`, `build`
   - Look for `pom.xml`/`build.gradle`: `mvn verify`, `gradle check`
   - Detect the package manager from lockfile (npm/pnpm/yarn)

2. If `$ARGUMENTS` specifies particular checks, run only those. Otherwise run all detected checks.

3. Run all applicable checks in parallel using the Bash tool:
   - Each check runs as a separate parallel command
   - Capture stdout/stderr and exit codes for each

4. Report results:
   ```
   ## Check Results
   
   | Check | Status | Duration |
   |-------|--------|----------|
   | Lint | pass/fail | Xs |
   | Test | pass/fail | Xs |
   | Build | pass/fail | Xs |
   | Typecheck | pass/fail | Xs |
   
   ## Failures (if any)
   
   ### Lint
   [error output]
   
   ### Test
   [failed test names and output]
   ```

5. If any checks fail, ask the user:
   - **Fix all** — launch the **fixer** agent on each failure
   - **Fix specific** — let the user pick which failures to fix
   - **Just report** — end without fixing

## Edge Cases

- If no checks are detected, notify the user and suggest what scripts to add
- If a check doesn't exist but is requested, skip with a note
- Timeout long-running checks after 5 minutes with a warning
