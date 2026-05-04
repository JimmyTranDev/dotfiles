---
name: specify-test
description: Analyze test coverage gaps and write findings to a spec file in `spec/`
---

Usage: /specify-test [scope or description]

Analyze the project's test suite and identify coverage gaps for the specified area. This command is analysis-only — it does NOT write tests.

$ARGUMENTS

1. Run existing tests:
   - Detect the test runner from the project config (package.json scripts, Cargo.toml, Makefile, etc.)
   - Run the test suite and capture results — note passing, failing, and skipped tests
   - If tests fail, report the failures in the spec

2. Load skills: **code-follower** and optionally **code-conventions**, **ts-total-typescript**, **meta-shell-scripting**. Analyze coverage gaps across these categories:
   - **Untested code paths**: functions, branches, or modules with no test coverage at all
   - **Missing edge cases**: empty/null input, boundary values (0, max, negative), non-numeric input, empty collections
   - **Error handling**: failure cases (network, timeout, invalid input), error propagation, error message accuracy
   - **Business logic**: complex conditional logic, state transitions, calculations, data transformations
   - **Integration points**: API boundaries, database interactions, external service calls, event handlers
   - **Race conditions**: concurrent access, async ordering, timeout behavior

3. Prioritize the findings:
   - Rank coverage gaps by risk (high, medium, low) considering code criticality, complexity, and likelihood of bugs
   - For each gap, explain what is untested, why it matters, and what test cases would cover it

4. Write the coverage gap analysis to a spec file using the `test-` prefix per the `specify-*` conventions in AGENTS.md. Include:
   - Test suite results summary (passing, failing, skipped counts)
   - Coverage gaps grouped by category, ranked by risk
   - For each gap: file path, function/branch, suggested test cases, and risk level
   - Remaining areas needing attention

5. Print a brief summary to chat:
   - Spec file path
   - Total coverage gaps found
   - Top 3 highest-risk gaps
