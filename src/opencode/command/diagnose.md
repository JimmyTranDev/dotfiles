---
name: diagnose
description: Check code for logical errors, contradictions, and bugs, then fix them
---

Analyze the specified code (files, directories, or the area described in the user's prompt) for logical soundness issues and bugs, then apply fixes.

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a symptom or behavior, trace it back to the relevant code
   - If no scope is given, analyze recent changes via `git diff` and `git diff --cached`
   - Run tests or build commands if available to identify existing failures

2. Check for logical soundness issues:
   - **Contradictions**: Conditions that can never be true, conflicting checks, mutually exclusive branches that are both expected to execute
   - **Impossible states**: State combinations that should be unreachable but aren't guarded against
   - **Invalid assumptions**: Code that assumes properties about data that aren't guaranteed (nullability, array length, type narrowing)
   - **Off-by-one errors**: Incorrect loop bounds, fence-post problems, inclusive vs exclusive range mistakes
   - **Race conditions**: Concurrent access without synchronization, async operations with missing awaits, stale closures
   - **Missing edge cases**: Unhandled empty inputs, boundary values, negative numbers, undefined/null paths
   - **Incorrect operator usage**: Wrong comparison operators, bitwise vs logical, assignment vs equality
   - **Broken control flow**: Unreachable code after returns, missing break statements, incorrect early returns

3. Check for bugs:
   - **Runtime errors**: Null dereferences, index out of bounds, type mismatches
   - **Logic errors**: Inverted conditions, wrong variable used, incorrect return values
   - **Resource leaks**: Unclosed connections, missing cleanup, dangling event listeners
   - **Error handling**: Swallowed errors, missing try/catch, incorrect error propagation
   - **Data integrity**: Mutations of shared state, incorrect cloning, reference vs value issues

4. Fix identified issues:
   - Apply minimal, surgical fixes that correct the problem without changing unrelated behavior
   - Prioritize fixes by severity — crashes and data corruption first, then logic errors, then edge cases
   - Verify each fix doesn't introduce new issues

5. Load relevant skills and delegate to specialized agents in parallel where applicable:

   Skills to load:
   - **logic-checker**: Load to reference the checklist for contradictions, invalid assumptions, and logical gaps
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
