---
name: audit-check
description: Run lint, test, build, and typecheck in parallel and report combined results
---

Usage: /audit-check [specific checks]

$ARGUMENTS

Run project quality checks (lint, test, build, typecheck) in parallel and report combined results.

## Workflow

1. Run `detect-stack.sh` to identify the project type, package manager, test runner, and linter. Use the output to determine which checks are available.
   - If `$ARGUMENTS` specifies particular checks, run only those. Otherwise run all detected checks.

2. Run all applicable checks in parallel using the Bash tool:
   - Lint: `lint-check.sh`
   - Tests: `run-tests.sh`
   - Build/typecheck: use the package manager detected by `detect-stack.sh`

3. Report results:
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

4. If any checks fail, ask the user:
   - **Fix all** — launch the **fixer** agent on each failure
   - **Fix specific** — let the user pick which failures to fix
   - **Just report** — end without fixing

## Edge Cases

- If no checks are detected, notify the user and suggest what scripts to add
- If a check doesn't exist but is requested, skip with a note
- Timeout long-running checks after 5 minutes with a warning
