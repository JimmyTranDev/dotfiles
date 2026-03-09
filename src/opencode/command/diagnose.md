---
name: diagnose
description: Check code for logical errors, contradictions, and bugs, then fix them
---

Usage: /diagnose [scope or symptom description]

Analyze the specified code for logical soundness issues and bugs, then apply fixes.

$ARGUMENTS

1. **Create a worktree** following the Worktree Workflow in AGENTS.md — name the branch after the issue being diagnosed

2. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a symptom or behavior, trace it back to the relevant code
   - If no scope is given, analyze recent changes via `git diff` and `git diff --cached`
   - Run tests or build commands if available to identify existing failures

3. Load the **logic-checker** skill and use its checklists to systematically scan for logical soundness issues (contradictions, impossible states, invalid assumptions, off-by-one errors, race conditions, missing edge cases, broken control flow) and bugs (runtime errors, logic errors, resource leaks, error handling, data integrity)

4. Fix identified issues:
   - Apply minimal, surgical fixes that correct the problem without changing unrelated behavior
   - Prioritize fixes by severity — crashes and data corruption first, then logic errors, then edge cases
   - Verify each fix doesn't introduce new issues

5. Load relevant skills and delegate to specialized agents in parallel where applicable:

   Skills to load:
   - **convention-matcher**: Load to ensure fixes match codebase conventions

   Agents to delegate to:
   - **fixer**: Use for each identified bug to diagnose root cause and apply minimal surgical fixes
   - **reviewer**: Use after all fixes are applied to verify correctness and catch anything missed
   - **tester**: Use to run existing tests and add tests for any bugs that lacked coverage
   - **auditor**: Use if any issues touch security-sensitive code (auth, data handling, input validation)

6. After fixing:
   - Run the project's test suite and build to confirm fixes work and nothing else broke
   - Summarize each issue found: what was wrong, why it was wrong, and how it was fixed
   - Categorize findings by severity (critical, major, minor)

7. **Commit, merge, and clean up** the worktree following the Worktree Workflow in AGENTS.md
