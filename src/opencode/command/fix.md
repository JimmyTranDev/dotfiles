---
name: fix
description: Investigate and fix a bug from a symptom, error, or failing test
---

Usage: /fix <description of the bug, error message, or failing test>

Investigate the reported issue and apply a minimal, surgical fix.

$ARGUMENTS

1. Understand the problem:
   - Parse the error message, stack trace, failing test, or symptom description
   - If the user provides a file path or line number, start there
   - If the description is vague, search the codebase for related code before asking clarifying questions

2. Reproduce and trace:
   - Run the failing test or build command if one is available to confirm the issue
   - Trace from the symptom to the root cause — follow the data flow, check call sites, inspect types
   - Identify whether this is a logic error, type error, missing edge case, race condition, or configuration issue

3. Apply the fix:
   - Make the smallest change that correctly addresses the root cause — do not refactor surrounding code
   - Preserve existing conventions and patterns
   - If the fix requires changes in multiple files, explain why each change is necessary

4. Verify the fix:
   - Run the failing test or build command again to confirm the fix resolves the issue
   - Check for regressions by running the broader test suite if available
   - If no tests exist for the fixed code path, note this but do not add tests unless the user asks

5. Load applicable skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Skills to load (load all applicable skills in a single parallel batch):
   - **follower**: Always load to match existing codebase conventions
   - **logic-checker**: Load when the bug involves complex business logic or state management

   Agents to delegate to:
   - **fixer**: Delegate the core investigation and fix — this is the primary agent for /fix
   - **tester**: Launch after the fix is applied to verify test coverage and add tests if needed
   - **reviewer**: Launch in parallel with tester to verify the fix is correct and doesn't introduce new issues

Report what the root cause was, what was changed, and how it was verified.
