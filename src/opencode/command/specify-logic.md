---
name: specify-logic
description: Analyze code for logic errors, contradictions, invalid assumptions, and missing edge cases and write spec to `spec/logic/`
---

Usage: /specify-logic [scope or description]

Analyze the specified code for logical correctness — contradictions, invalid assumptions, impossible states, missing edge cases, and flawed reasoning — and write findings to a spec file.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a feature or behavior, search the codebase to locate the relevant code
   - If no scope is given, analyze the full codebase

2. Load all applicable skills in parallel (**code-logic-checker**, **code-soundness**, **code-follower**, and optionally **code-conventions**, **ts-total-typescript**), then analyze the code for logic issues across these categories:
   - **Internal consistency**: Contradictory conditions, mutually exclusive branches that overlap, impossible states that aren't prevented
   - **Completeness**: Missing branches, unhandled enum variants, gaps in state transitions, switch/if chains that don't cover all cases
   - **Boundary behavior**: Off-by-one errors, empty collections, zero/null/undefined, max values, negative numbers, integer overflow
   - **Boolean logic**: Flipped conditions, De Morgan's law violations, negation errors, short-circuit evaluation assumptions
   - **Data flow**: Inputs that aren't validated, type narrowing lost across function boundaries, values that can be stale or undefined
   - **Temporal correctness**: Race conditions, ordering assumptions, stale data reads, async operations that assume sequential execution
   - **State transitions**: Missing states, invalid transitions, terminal states with outgoing edges, unreachable states, transitions that skip required intermediates

3. For each finding:
   - Give it a short, clear name
   - Include the file path and line number
   - Describe the logic error and its consequence in 1-2 sentences
   - Classify severity (critical, major, minor, warning) using these criteria:
     - **Critical**: Corrupts data, causes security bypass, or crashes the system
     - **Major**: Produces wrong results under common conditions
     - **Minor**: Only manifests under rare edge cases
     - **Warning**: Valid logic that is fragile and likely to break with future changes
   - Suggest a concrete fix

4. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - Group findings by category from step 2
   - Within each category, rank by severity (critical first)
   - Include a "Sound Logic" section noting what is correct and well-reasoned
   - Include a "Fragile Assumptions" section for logic that works now but could break
   - End with a verdict: Sound / Minor issues / Fundamental flaws

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Analyze code for correctness issues and design problems that indicate logic flaws
   - **auditor**: Scan for security-related logic errors (auth bypasses, permission checks, input validation)

6. Summarize the analysis:
   - Report total findings by category and severity
   - Highlight the most critical logic errors that need immediate attention
   - Suggest which `/command` to run to address each finding (e.g., `/fix`, `/implement`)

7. Write findings to a spec file:
   - Create `spec/logic/` directory if it doesn't exist
   - Choose filename: if a scope or description was given, convert it to kebab-case (e.g., `auth-flow.md`); otherwise use a timestamp (e.g., `2026-04-23T12-00-00.md`)
   - If a file with the chosen name already exists, append a timestamp suffix before the extension (e.g., `auth-flow-2026-04-23T12-00-00.md`)
   - Write all findings to the file in the same structured format: categories, severity rankings, Sound Logic section, Fragile Assumptions section, and verdict
   - Include each item's file location, severity, description, and suggested fix
   - Print a brief summary to chat: the spec file path, total findings count, and the top 3 most critical items
