---
name: specify-fix
description: Specify skill for bug investigation — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`fix-`

## Skills to Load

- **code-follower**: Match existing codebase conventions
- **code-logic-checker**: Find contradictions, invalid assumptions, logical gaps
- **code-soundness**: Find suspicious patterns and anomalies
- **code-conventions**: Coding conventions (optional)
- **ts-total-typescript**: TypeScript patterns (optional)
- **meta-shell-scripting**: Shell scripting conventions (optional)

## Agents to Launch

- **fixer**: Investigate the root cause and propose the minimal surgical fix
- **reviewer**: Review the proposed fix approach for correctness and unintended side effects
- **auditor**: Check if the bug has security implications

## Analysis Categories

- **Root cause**: What is fundamentally wrong and why does it manifest as this symptom
- **Blast radius**: What other code paths, features, or users are affected by this bug
- **Regression risk**: What could break if the fix is applied incorrectly
- **Related issues**: Are there similar patterns elsewhere in the codebase that might have the same bug

### Investigation Process

1. Parse the error message, stack trace, failing test, or symptom description
2. Run the failing test or build command to confirm the issue
3. Trace from symptom to root cause — follow data flow, check call sites, inspect types
4. Identify whether this is a logic error, type error, missing edge case, race condition, or configuration issue
5. Document the full call chain from symptom to root cause

### Fix Specification

For each issue found:
- Short, clear name
- File path and line number
- Bug description and impact (1-2 sentences)
- Concrete fix with specific code changes needed
- Verification plan (test commands, manual steps)
- Order fixes by dependency (which changes must come first)

## Severity Classification

- **Critical**: Corrupts data, causes security bypass, or crashes the system
- **Major**: Produces wrong results under common conditions
- **Minor**: Only manifests under rare edge cases
- **Warning**: Valid logic that is fragile and likely to break with future changes

## Scope Overrides

- If the user provides a file path or line number, start there
- If the description is vague, search the codebase for related code before asking clarifying questions
