---
name: specify-ci
description: Specify skill for CI failure investigation — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`ci-`

## Skills to Load

- **code-follower**: Match existing codebase conventions
- **code-logic-checker**: Find contradictions and logical gaps

## Agents to Launch

- **fixer**: Investigate root causes of independent failures in parallel
- **reviewer**: Verify root cause analysis is accurate

## Analysis Categories

### Failure Categories

- **Build errors**: TypeScript, compilation, or bundling failures
- **Test failures**: Unit, integration, or e2e test failures
- **Lint errors**: ESLint, Prettier, or other linting tool failures
- **Dependency errors**: Install failures, missing packages, version conflicts
- **Configuration errors**: Workflow YAML issues, missing secrets, environment problems
- **Flaky/infra**: Timeouts, network errors, runner issues (flag as non-actionable)

### Investigation Process

- Fetch CI status: `gh run list --branch $(git branch --show-current) --limit 5 --json databaseId,status,conclusion,name,event,headSha`
- For each failing run: `gh run view <run-id> --json jobs` and `gh run view <run-id> --log-failed`
- Parse logs for error messages, failing steps, exit codes, and stack traces
- For test failures: read the failing test and code under test
- For build/lint errors: trace to source file and identify the violation
- For dependency errors: check package.json, lockfile, and install commands
- For configuration errors: inspect `.github/workflows/` YAML files

## Severity Classification

- **Build-breaking**: Prevents any artifact from being produced
- **Test failures**: Code is broken or tests are wrong
- **Lint**: Code style violations
- **Configuration**: Workflow misconfiguration
- **Flaky**: Non-actionable infrastructure issues

## Scope Overrides

- If `$ARGUMENTS` contains a run ID or workflow name, focus on that specific run
- Otherwise, select all runs with `conclusion` of `failure` or `startup_failure`
- If no failing runs are found, notify the user and stop
