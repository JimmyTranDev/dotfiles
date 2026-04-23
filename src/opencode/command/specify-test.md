---
name: specify-test
description: Run tests and add or improve test coverage for specified code and write spec to `spec/`
---

Usage: /specify-test [scope or description]

Run the project's test suite and add or improve test coverage for the specified area.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files, functions, or modules, focus test coverage on those
   - If the user describes a feature or behavior, locate the relevant code first
   - If no scope is given, run the full test suite and identify areas with missing coverage

2. Run existing tests:
   - Detect the test runner from the project config (package.json scripts, Cargo.toml, Makefile, etc.)
   - Run the test suite and capture results — note passing, failing, and skipped tests
   - If tests fail, report the failures before proceeding

3. Load all applicable skills in parallel (**code-follower** and optionally **code-conventions**, **ts-total-typescript**, **meta-shell-scripting**), then analyze coverage gaps across these categories:
   - **Untested code paths**: functions, branches, or modules with no test coverage at all
   - **Missing edge cases**: empty/null input, boundary values (0, max, negative), non-numeric input, empty collections
   - **Error handling**: failure cases (network, timeout, invalid input), error propagation, error message accuracy
   - **Business logic**: complex conditional logic, state transitions, calculations, data transformations
   - **Integration points**: API boundaries, database interactions, external service calls, event handlers
   - **Race conditions**: concurrent access, async ordering, timeout behavior

4. Prioritize the findings:
   - Rank coverage gaps by risk (high, medium, low) considering code criticality, complexity, and likelihood of bugs
   - For each gap, explain what is untested, why it matters, and what test cases would cover it

5. Write tests:
   - Follow existing test conventions exactly — same framework, same patterns, same file structure
   - Structure tests using AAA (Arrange, Act, Assert) pattern
   - Use descriptive test names that explain the expected behavior
   - Keep tests focused — one assertion per logical concept
   - Mock external dependencies, not your own code
   - Cover happy paths, edge cases, error conditions, and boundary values

6. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **tester**: Primary agent — writes tests, verifies coverage, ensures test quality
   - **reviewer**: Launch after tests are written to verify test correctness and completeness

7. After writing tests:
   - Run the full test suite to confirm all new tests pass and no existing tests broke
   - If any tests fail, fix them before finishing
   - Summarize each test added: what behavior it covers, what gap it fills, and the test result
   - List any remaining coverage gaps that were out of scope but worth noting

8. Write coverage gap analysis to `spec/`:
   - Create the `spec/` directory if it doesn't exist
   - Choose the filename:
     - Use the `test-` prefix followed by a descriptive kebab-case name based on the scope or key findings (e.g., `spec/test-user-authentication.md`, `spec/test-api-error-paths.md`)
     - If a file with the chosen name already exists, append a numeric suffix (e.g., `spec/test-user-authentication-2.md`)
   - Write the spec file containing:
     - Test results summary (total, passing, failing, skipped)
     - Tests added in this run with descriptions
     - Remaining coverage gaps with risk level and suggested test approach for each
     - Areas needing more coverage grouped by category

9. Print a brief summary to chat as the final response:
   - Spec file path
   - Number of tests added
   - Number of remaining coverage gaps
