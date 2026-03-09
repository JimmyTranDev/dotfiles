---
name: diagnose
description: Check code for logical errors, contradictions, and bugs, then fix them
---

Usage: /diagnose [scope or symptom description]

Analyze the specified code for logical soundness issues and bugs, then apply fixes.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a symptom or behavior, trace it back to the relevant code
   - If no scope is given, analyze recent changes via `git diff` and `git diff --cached`
   - Run tests or build commands if available to identify existing failures

2. Load the **logic-checker** and **convention-matcher** skills in parallel, then use the logic-checker checklists to systematically scan for logical soundness issues (contradictions, impossible states, invalid assumptions, off-by-one errors, race conditions, missing edge cases, broken control flow) and bugs (runtime errors, logic errors, resource leaks, error handling, data integrity)

3. Fix identified issues:
   - Apply minimal, surgical fixes that correct the problem without changing unrelated behavior
   - Prioritize fixes by severity — crashes and data corruption first, then logic errors, then edge cases
   - Verify each fix doesn't introduce new issues

4. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **fixer**: Use for each identified bug — launch multiple fixer agents in parallel for independent bugs that don't affect the same code
   - **reviewer** + **tester**: Launch in parallel after fixes are applied — reviewer verifies correctness while tester runs tests and adds coverage
   - **auditor**: Launch in parallel with reviewer + tester if any issues touch security-sensitive code

5. After fixing:
   - Run the project's test suite and build to confirm fixes work and nothing else broke
   - Summarize each issue found: what was wrong, why it was wrong, and how it was fixed
   - Categorize findings by severity (critical, major, minor)
