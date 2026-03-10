---
name: check-soundness
description: Verify the logical soundness and correctness of a feature without modifying code
---

Usage: /check-soundness $ARGUMENTS

Analyze the specified feature for logical soundness, contradictions, invalid assumptions, and correctness issues. This is a read-only analysis — do not modify any code.

$ARGUMENTS

1. Understand the feature scope:
   - If the user specifies files, directories, or a feature name, focus on those
   - If the user describes a feature by behavior, trace it through the codebase to find all relevant code
   - If no scope is given, ask the user to specify which feature to analyze

2. Map the feature:
   - Identify all files, functions, types, and data flows involved in the feature
   - Trace the feature's entry points, processing logic, and exit points
   - Identify external dependencies and integration points

3. Load the **logic-checker** skill, then systematically check for:
   - **Contradictions**: Conflicting conditions, mutually exclusive states that can coexist, conflicting business rules
   - **Invalid assumptions**: Assumed non-null values, assumed array lengths, assumed ordering, assumed type narrowing
   - **Missing edge cases**: Empty inputs, boundary values, concurrent access, error propagation paths
   - **Impossible states**: State machines with unreachable states, dead code branches, redundant checks
   - **Control flow issues**: Unreachable code, fallthrough errors, missing return paths, infinite loops
   - **Data integrity**: Race conditions, stale data, missing validation, type mismatches at boundaries

4. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch all applicable agents in parallel — they analyze the same feature independently):
   - **reviewer**: Analyze the feature for correctness, design issues, and potential bugs
   - **auditor**: Check for security implications if the feature handles user input, authentication, or sensitive data
   - **solver**: Investigate any unclear cross-system interactions or complex logic paths

5. Report findings:
   - Categorize each issue by severity (critical, major, minor)
   - For each issue: describe what is wrong, why it is wrong, and what the correct behavior should be
   - Highlight any assumptions that are valid now but fragile (could break with future changes)
   - Provide a summary verdict: whether the feature is logically sound, has minor issues, or has fundamental flaws

Do not apply fixes. Present findings only so the user can decide how to proceed.
