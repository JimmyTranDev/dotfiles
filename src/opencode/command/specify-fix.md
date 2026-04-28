---
name: specify-fix
description: Investigate a bug or issue, analyze root cause, and write a fix spec to `spec/`
---

Usage: /specify-fix <description of the bug, error message, or failing test>

Investigate the reported issue, trace the root cause, and write a structured fix spec — without applying any changes.

$ARGUMENTS

1. Understand the problem:
   - Parse the error message, stack trace, failing test, or symptom description
   - If the user provides a file path or line number, start there
   - If the description is vague, search the codebase for related code before asking clarifying questions

2. Reproduce and trace:
   - Run the failing test or build command if one is available to confirm the issue
   - Trace from the symptom to the root cause — follow the data flow, check call sites, inspect types
   - Identify whether this is a logic error, type error, missing edge case, race condition, or configuration issue
   - Document the full call chain from symptom to root cause

3. Load all applicable skills in parallel (**code-follower**, **code-logic-checker**, **code-soundness**, and optionally **code-conventions**, **ts-total-typescript**, **meta-shell-scripting**), then analyze the bug across these dimensions:
   - **Root cause**: What is fundamentally wrong and why does it manifest as this symptom
   - **Blast radius**: What other code paths, features, or users are affected by this bug
   - **Regression risk**: What could break if the fix is applied incorrectly
   - **Related issues**: Are there similar patterns elsewhere in the codebase that might have the same bug

4. For the root cause and each related issue found:
   - Give it a short, clear name
   - Include the file path and line number
   - Describe the bug and its impact in 1-2 sentences
   - Classify severity (critical, major, minor, warning) using these criteria:
     - **Critical**: Corrupts data, causes security bypass, or crashes the system
     - **Major**: Produces wrong results under common conditions
     - **Minor**: Only manifests under rare edge cases
     - **Warning**: Valid logic that is fragile and likely to break with future changes
   - Propose a concrete fix with specific code changes needed

5. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - Start with a clear root cause summary
   - List all affected files and the changes each needs
   - Order proposed fixes by dependency (which changes must come first)
   - Include a "Verification Plan" section describing how to confirm the fix works (test commands, manual steps)

6. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **fixer**: Investigate the root cause and propose the minimal surgical fix
   - **reviewer**: Review the proposed fix approach for correctness and unintended side effects
   - **auditor**: Check if the bug has security implications

7. Write findings to a spec file:
   - Create the `spec/` directory if it doesn't exist
   - Choose the filename: use the `fix-` prefix followed by a descriptive kebab-case name based on the bug (e.g., `spec/fix-null-pointer-in-auth.md`, `spec/fix-race-condition-payment-flow.md`)
   - If a file with the chosen name already exists, append a numeric suffix (e.g., `spec/fix-null-pointer-in-auth-2.md`)
   - Write the full analysis: root cause, blast radius, all findings with severity, proposed fixes in dependency order, verification plan, and related issues
   - Print a brief summary to chat: the spec file path, root cause in one sentence, severity, and number of files that need changes

8. After completing the analysis, load the **meta-skill-learnings** skill and improve any relevant skills with reusable patterns, gotchas, or anti-patterns discovered during the analysis.
