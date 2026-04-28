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

3. Load skills: **code-follower**, **code-logic-checker**, **code-soundness**, and optionally **code-conventions**, **ts-total-typescript**, **meta-shell-scripting**. Analyze the bug across these dimensions:
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
   - Start with a clear root cause summary
   - List all affected files and the changes each needs
   - Order proposed fixes by dependency (which changes must come first)
   - Include a "Verification Plan" section describing how to confirm the fix works (test commands, manual steps)

6. Launch agents in parallel:
   - **fixer**: Investigate the root cause and propose the minimal surgical fix
   - **reviewer**: Review the proposed fix approach for correctness and unintended side effects
   - **auditor**: Check if the bug has security implications

7. Write findings to a spec file using the `fix-` prefix per the `specify-*` conventions in AGENTS.md.
