---
name: test
description: Run tests, analyze failures, and add missing test coverage for specified code
---

Run tests and improve test coverage for the specified code.

Usage: /test [scope]

1. Determine the scope:
   - If the user specifies files, directories, or a feature, focus on those
   - If no scope is given, run the full test suite to identify existing failures

2. Run existing tests:
   - Detect the test runner (Vitest, Jest, pytest, etc.) from project configuration
   - Run tests and capture output
   - If tests fail, categorize failures by type (logic error, missing mock, stale snapshot, etc.)

3. Load **follower** skill, then delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to:
   - **tester** + **fixer**: If there are both test coverage gaps and source code bugs causing failures, launch tester (for writing new tests) and fixer (for source code bugs) in parallel since they address independent problems
   - If all failures stem from the same root cause, run **fixer** first, then **tester** sequentially

4. After changes:
   - Re-run the test suite to confirm all tests pass
   - Summarize what was tested, what was added, and current coverage status
