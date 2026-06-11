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
   - Run the failing test or build command if one is available to confirm the issue (use `run-tests.sh` to auto-detect the test runner)
   - Trace from the symptom to the root cause — follow the data flow, check call sites, inspect types
   - Identify whether this is a logic error, type error, missing edge case, race condition, or configuration issue

3. Apply the fix:
   - Make the smallest change that correctly addresses the root cause — do not refactor surrounding code
   - Preserve existing conventions and patterns
   - If the fix requires changes in multiple files, explain why each change is necessary

4. Verify the fix:
   - Run the failing test or build command again to confirm the fix resolves the issue
   - Check for regressions by running `run-tests.sh` for the broader test suite if available
   - If no tests exist for the fixed code path, note this but do not add tests unless the user asks

5. Load applicable skills and delegate to agents:

    Skills to load in a single parallel batch:
     - **code-follower**: Always load to match existing codebase conventions
     - **code-logic-checker**: Load when the bug involves complex business logic or state management
     - **code-soundness**: Always load to catch suspicious patterns, anomalies, and things that look wrong
     - **test**: Load when the user asks for test verification
     - Tech-stack-specific skills (run `detect-stack.sh` to determine):
       - Java (pom.xml/build.gradle/**.java) → load **java-spring-senior** and **review-backend**
       - TypeScript/React (tsconfig.json/**.tsx) → load **review-frontend** and **ts-total-typescript**
       - React Native → load **review-mobile**
       - Shell scripts → load **meta-shell-scripting**
     - **security**: Load when the bug touches authentication, authorization, data validation, or external inputs

    Agents to delegate to:
    - **fixer**: Delegate the core investigation and fix — this is the primary agent for /fix
    - **tester**: Launch only if the user explicitly asks for tests
    - **reviewer**: Launch after the fix to verify it is correct and doesn't introduce new issues
Report what the root cause was, what was changed, and how it was verified.
