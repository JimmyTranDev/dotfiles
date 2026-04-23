---
name: specify-ci
description: Investigate failing GitHub Actions workflows on the current branch and report root causes without making changes and write spec to `spec/ci/`
---

Usage: /specify-ci [$ARGUMENTS]

Investigate failing GitHub Actions workflows on the current branch, identify the root cause of each failure, and report findings without applying any fixes. Write all findings to a spec file.

$ARGUMENTS

Load the **code-follower** and **code-logic-checker** skills in parallel.

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

5. Investigate root causes — launch **fixer** agents in parallel for independent failures:
   - Each **fixer** receives the error context (log output, failing file, line number) and searches the local codebase to identify the root cause
   - For test failures: read the failing test and the code under test to understand the mismatch
   - For build/lint errors: trace the error to the source file and identify the violation
   - For dependency errors: check `package.json`, lockfile, and install commands
   - For configuration errors: inspect `.github/workflows/` YAML files

6. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - For each failure, include: workflow name, job name, error category, root cause description, file path and line number, and a concrete suggested fix
   - Flag flaky/infrastructure failures as non-actionable
   - Rank by severity: build-breaking > test failures > lint > configuration > flaky

7. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **fixer**: Investigate root causes of independent failures in parallel
   - **reviewer**: Verify root cause analysis is accurate

8. Write findings to a spec file:
   - Create the `spec/ci/` directory if it doesn't exist
   - Choose the filename: use the branch name in kebab-case (e.g., `feature-auth.md`); if a file with that name already exists, append a timestamp suffix
   - Write all findings to the file: table of failures with workflow name, job name, error category, root cause, file location, suggested fix, and status (actionable/flaky)
   - Print a brief summary to chat: the spec file path, total failures found, and any build-breaking issues
