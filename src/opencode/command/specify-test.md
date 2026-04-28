---
name: specify-test
description: Run tests and add or improve test coverage for specified code and write spec to `spec/`
---

Usage: /specify-test [scope or description]

Run the project's test suite and add or improve test coverage for the specified area.

$ARGUMENTS

1. Run existing tests:
   - Detect the test runner from the project config (package.json scripts, Cargo.toml, Makefile, etc.)
   - Run the test suite and capture results — note passing, failing, and skipped tests
   - If tests fail, report the failures before proceeding

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

4. Write tests:
   - Follow existing test conventions exactly — same framework, same patterns, same file structure
   - Structure tests using AAA (Arrange, Act, Assert) pattern
   - Use descriptive test names that explain the expected behavior
   - Keep tests focused — one assertion per logical concept
   - Mock external dependencies, not your own code
   - Cover happy paths, edge cases, error conditions, and boundary values

5. Launch agents in parallel:
   - **tester**: Primary agent — writes tests, verifies coverage, ensures test quality
   - **reviewer**: Launch after tests are written to verify test correctness and completeness

6. After writing tests:
   - Run the full test suite to confirm all new tests pass and no existing tests broke
   - If any tests fail, fix them before finishing
   - Summarize each test added: what behavior it covers, what gap it fills, and the test result
   - List any remaining coverage gaps that were out of scope but worth noting

7. Write coverage gap analysis to a spec file using the `test-` prefix per the `specify-*` conventions in AGENTS.md. Include test results summary, tests added, remaining coverage gaps with risk level, and areas needing more coverage grouped by category.

8. Print a brief summary to chat:
   - Spec file path
   - Number of tests added
   - Number of remaining coverage gaps
