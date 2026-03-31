---
name: test
description: Run tests and add or improve test coverage for specified code
---

Usage: /test [scope or description]

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

3. Analyze coverage gaps:
   - Identify untested code paths, edge cases, and error handling branches
   - Prioritize by risk: critical paths and complex logic first, simple getters/setters last
   - Check for existing test patterns and conventions in the project (test file location, naming, utilities, mocks)

4. Write tests:
   - Follow existing test conventions exactly — same framework, same patterns, same file structure
   - Cover happy paths, edge cases, error conditions, and boundary values
   - Use descriptive test names that explain the expected behavior
   - Keep tests focused — one assertion per logical concept

5. Verify:
   - Run the full test suite to confirm all new tests pass and no existing tests broke
   - If any tests fail, fix them before finishing

6. Load applicable skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Skills to load (load all applicable skills in a single parallel batch):
   - **follower**: Always load to match existing test conventions and patterns

   Agents to delegate to:
   - **tester**: Primary agent — writes tests, verifies coverage, ensures test quality
   - **reviewer**: Launch after tests are written to verify test correctness and completeness

Report what tests were added, what coverage gaps remain, and the final test suite result.
