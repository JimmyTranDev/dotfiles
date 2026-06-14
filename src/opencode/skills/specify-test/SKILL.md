---
name: specify-test
description: Specify skill for test coverage analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`test-`

## Skills to Load

- **code-follower**: Match existing codebase conventions
- **code-conventions**: Coding conventions (optional)
- **ts-total-typescript**: TypeScript patterns (optional)
- **meta-shell-scripting**: Shell scripting conventions (optional)

## Agents to Launch

None required.

## Analysis Categories

- **Untested code paths**: Functions, branches, or modules with no test coverage at all
- **Missing edge cases**: Empty/null input, boundary values (0, max, negative), non-numeric input, empty collections
- **Error handling**: Failure cases (network, timeout, invalid input), error propagation, error message accuracy
- **Business logic**: Complex conditional logic, state transitions, calculations, data transformations
- **Integration points**: API boundaries, database interactions, external service calls, event handlers
- **Race conditions**: Concurrent access, async ordering, timeout behavior

### Process

1. Detect test runner from project config
2. Run the test suite and capture results (passing, failing, skipped)
3. If tests fail, report failures in the spec
4. Analyze coverage gaps across the categories above

### Spec Output

- Test suite results summary (passing, failing, skipped counts)
- Coverage gaps grouped by category, ranked by risk
- For each gap: file path, function/branch, suggested test cases, and risk level

## Severity Classification

Rank by risk:
- **High**: Critical business logic, security-sensitive code, frequently modified code with no tests
- **Medium**: Utility functions, edge cases in important paths
- **Low**: Stable code with low change frequency

## Scope Overrides

None — uses default scope detection.
