---
name: test
description: Run tests, analyze failures, and add missing test coverage for specified code
---

Run tests and improve test coverage for the specified code.

Usage: /test [scope]

1. **Create a worktree** following the Worktree Workflow in AGENTS.md — name the branch after the test scope

2. Determine the scope:
   - If the user specifies files, directories, or a feature, focus on those
   - If no scope is given, run the full test suite to identify existing failures

3. Run existing tests:
   - Detect the test runner (Vitest, Jest, pytest, etc.) from project configuration
   - Run tests and capture output
   - If tests fail, categorize failures by type (logic error, missing mock, stale snapshot, etc.)

4. Load relevant skills and delegate to specialized agents:

   Skills to load:
   - **convention-matcher**: Load to ensure new tests match existing test conventions in the codebase

   Agents to delegate to:
   - **tester**: Primary agent — analyzes code paths, writes new tests for uncovered behavior, fixes broken tests
   - **fixer**: Use for each test failure that stems from a bug in the source code (not the test itself)

5. After changes:
   - Re-run the test suite to confirm all tests pass
   - Summarize what was tested, what was added, and current coverage status

6. **Commit, merge, and clean up** the worktree following the Worktree Workflow in AGENTS.md
