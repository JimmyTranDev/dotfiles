---
name: fix
description: Investigate bugs, logical errors, and cross-system issues, then fix them
---

Usage: /fix [scope, symptom, or description]

Investigate the described problem, trace it to its root cause, and implement a fix.

$ARGUMENTS

1. Understand the scope:
   - If the user describes a symptom, error message, or unexpected behavior, start from there
   - If the user specifies files or directories, focus investigation on those
   - If no details are given, check `git diff`, `git diff --cached`, and recent test/build output for clues

2. Reproduce and gather evidence (run independent commands in parallel):
   - Run the project's test suite or build to observe failures firsthand
   - Search for error messages, stack traces, or related patterns in the codebase
   - Trace data flow and call chains from the symptom back toward the root cause

3. Load **logic-checker** and **convention-matcher** skills in parallel, then use the logic-checker checklists to systematically scan for:
   - Logical soundness issues (contradictions, impossible states, invalid assumptions, off-by-one errors, race conditions, missing edge cases, broken control flow)
   - Bugs (runtime errors, logic errors, resource leaks, error handling, data integrity)

4. Delegate to the **fixer** agent with all gathered context — the fixer will:
   - Analyze the problem across system boundaries
   - Form and test hypotheses about root cause
   - Narrow down to the exact source of the issue

5. Apply fixes:
   - Implement the minimal change that addresses the root cause, not just the symptom
   - Prioritize by severity — crashes and data corruption first, then logic errors, then edge cases
   - Verify fixes resolve the original problem without introducing regressions

6. Delegate to additional agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel after fix):
   - **fixer**: Use for each identified bug — launch multiple fixer agents in parallel for independent bugs in different files
   - **reviewer** + **tester**: Launch in parallel — reviewer verifies correctness while tester runs tests and adds coverage
   - **auditor**: Launch in parallel with reviewer + tester if any issues touch security-sensitive code

7. After fixing:
   - Run the project's test suite and build to confirm fixes work
   - Summarize each issue found: what was wrong, what the root cause was, and how it was fixed
   - Categorize findings by severity (critical, major, minor)
