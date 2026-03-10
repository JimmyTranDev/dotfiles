---
name: solve
description: Investigate and fix unclear cross-system issues where the root cause is unknown
---

Usage: /solve $ARGUMENTS

Investigate the described problem, trace it to its root cause, and implement a fix.

$ARGUMENTS

1. Understand the problem:
   - If the user describes a symptom, error message, or unexpected behavior, start from there
   - If the user specifies files or areas, focus investigation on those
   - If no details are given, check `git diff`, `git diff --cached`, and recent test/build output for clues

2. Reproduce and gather evidence (run independent commands in parallel):
   - Run the project's test suite or build to observe failures firsthand
   - Search for error messages, stack traces, or related patterns in the codebase
   - Trace data flow and call chains from the symptom back toward the root cause

3. Delegate to the **solver** agent with all gathered context — the solver will:
   - Analyze the problem across system boundaries
   - Form and test hypotheses about root cause
   - Narrow down to the exact source of the issue

4. Apply the fix:
   - Implement the minimal change that addresses the root cause, not just the symptom
   - Verify the fix resolves the original problem without introducing regressions

5. Delegate to additional agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel after fix):
   - **reviewer**: Verify the fix is correct and doesn't break existing behavior
   - **tester**: Run tests and add coverage for the discovered issue

6. After fixing:
   - Run the project's test suite and build to confirm the fix works
   - Summarize the investigation: what the symptom was, what the root cause was, and how it was fixed
