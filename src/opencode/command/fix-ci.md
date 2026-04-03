---
name: fix-ci
description: Investigate and fix failing GitHub Actions workflows on the current branch
---

Usage: /fix-ci [$ARGUMENTS]

Investigate failing GitHub Actions workflows on the current branch, identify the root cause of each failure, and apply fixes.

$ARGUMENTS

Load the **follower** and **logic-checker** skills in parallel.

1. Identify the current branch and fetch CI status (run in parallel):
   - `git branch --show-current`
   - `gh run list --branch $(git branch --show-current) --limit 5 --json databaseId,status,conclusion,name,event,headSha`

2. Determine which runs to investigate:
   - If `$ARGUMENTS` contains a run ID or workflow name, focus on that specific run
   - Otherwise, select all runs with `conclusion` of `failure` or `startup_failure`
   - If no failing runs are found, notify the user and stop

3. For each failing run, fetch detailed failure info (run in parallel across runs):
   - `gh run view <run-id> --json jobs`
   - For each failed job: `gh run view <run-id> --log-failed`
   - Parse the logs to extract error messages, failing steps, exit codes, and relevant stack traces

4. Categorize the failures:
   - **Build errors**: TypeScript, compilation, or bundling failures
   - **Test failures**: Unit, integration, or e2e test failures
   - **Lint errors**: ESLint, Prettier, or other linting tool failures
   - **Dependency errors**: Install failures, missing packages, version conflicts
   - **Configuration errors**: Workflow YAML issues, missing secrets, environment problems
   - **Flaky/infra**: Timeouts, network errors, runner issues (flag these as non-actionable)

5. Investigate root causes — launch **fixer** agents in parallel for independent failures across different files:
   - Each **fixer** receives the error context (log output, failing file, line number) and searches the local codebase to identify and apply the minimal fix
   - For test failures: read the failing test and the code under test to understand the mismatch
   - For build/lint errors: trace the error to the source file and fix the violation
   - For dependency errors: check `package.json`, lockfile, and install commands
   - For configuration errors: inspect `.github/workflows/` YAML files

6. Verify fixes locally:
   - Run the same commands that failed in CI locally (e.g., `npm run build`, `npm test`, `npm run lint`, `npx tsc --noEmit`)
   - If a command fails, iterate on the fix (max 3 attempts per failure)
   - If a fix cannot be resolved, report it to the user and move on to the next failure

7. Stage and commit all fixes:
   - `git add -A`
   - Use the commit format from the **git-workflows** skill (load if not already loaded)
   - `git commit -m "🐛 fix(ci): <concise description of what was fixed>"`
   - If fixes span multiple unrelated categories, create separate commits per category

8. Report outcome to the user:
   - Table of each failure with: workflow name, job name, error category, and status (fixed/unfixed/flaky)
   - List of files changed
   - Any failures flagged as flaky or non-actionable that require manual attention
   - Remind the user to push and verify CI passes: `git push`

Important:
- Do not push automatically — let the user decide when to push
- Do not modify workflow YAML files unless the failure is clearly a configuration error in the YAML itself
- Flag flaky/infrastructure failures as non-actionable rather than attempting to fix them
- If no local reproduction is possible (e.g., CI-only secrets, specific runner environment), report the failure with as much context as possible and suggest manual steps
