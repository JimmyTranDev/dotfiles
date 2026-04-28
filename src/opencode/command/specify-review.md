---
name: specify-review
description: Review code for bugs, logic errors, design issues, and correctness problems and write spec to `spec/`
---

Usage: /specify-review [scope or description]

Analyze the specified code for bugs, logic errors, design issues, and correctness problems — report findings and write them to a spec file.

$ARGUMENTS

1. Determine the scope. If no scope is given, review the current branch's diff against the base branch:
   - Check if `develop` branch exists locally or as `origin/develop` — if so, use it as the base; otherwise fall back to `main` (or `origin/main`)
   - Run in parallel: `git diff <base-branch>...HEAD` and `git log --oneline <base-branch>..HEAD`
   - If no commits exist on the branch beyond the base, notify the user and stop

2. Load skills: **code-follower**, **code-logic-checker**, **code-soundness**, and optionally **code-conventions**, **strategy-pragmatic-programmer**, **ts-total-typescript**, **meta-shell-scripting**. Analyze the code for issues across these categories:
   - **Correctness**: Logic errors, wrong return values, incorrect conditionals, missing return paths, flawed comparisons
   - **Internal consistency**: Contradictory conditions, mutually exclusive branches that overlap, impossible states that aren't prevented
   - **Completeness**: Missing branches, unhandled enum variants, gaps in state transitions, switch/if chains that don't cover all cases
   - **Error handling**: Swallowed errors, missing try/catch, catch-all handlers that hide failures, unhandled promise rejections, missing error propagation
   - **Edge cases**: Null/undefined access, empty collections, boundary values, zero-length strings, negative numbers, overflow, off-by-one errors
   - **Boolean logic**: Flipped conditions, De Morgan's law violations, negation errors, short-circuit evaluation assumptions
   - **Data flow**: Inputs that aren't validated, type narrowing lost across function boundaries, values that can be stale or undefined
   - **Race conditions**: Async ordering bugs, missing awaits, shared mutable state, stale closures, fire-and-forget calls that should be awaited
   - **State management**: Impossible states, missing state transitions, stale state reads, derived state that can desync, terminal states with outgoing edges
   - **API contracts**: Mismatched types between caller and callee, undocumented assumptions about input shape, missing validation
   - **Security**: Injection vectors, auth bypasses, sensitive data exposure, missing input sanitization

3. For each finding:
   - Give it a short, clear name
   - Include the file path and line number
   - Describe the bug or issue and its potential impact in 1-2 sentences
   - Classify severity (critical, major, minor, warning) using these criteria:
     - **Critical**: Corrupts data, causes security bypass, or crashes the system
     - **Major**: Produces wrong results under common conditions
     - **Minor**: Only manifests under rare edge cases
     - **Warning**: Valid logic that is fragile and likely to break with future changes
   - Suggest a concrete fix

4. Present the analysis:
   - Group findings by category from step 2
   - Within each category, rank by severity (critical first)
   - Include a "Sound Logic" section noting what is correct and well-reasoned
   - Include a "Fragile Assumptions" section for logic that works now but could break
   - Highlight the top 3-5 most critical findings across all categories
   - End with a verdict: Sound / Minor issues / Fundamental flaws

5. Launch agents in parallel:
   - **reviewer**: Catches bugs, design issues, and provides actionable feedback
   - **auditor**: Scans for security vulnerabilities and exploitable bugs
   - **optimizer**: Identifies performance concerns if the code introduces potentially expensive operations

6. Summarize the analysis:
   - Report total findings by category and severity
   - Highlight the most critical items that need immediate attention
   - Suggest which `/command` to run to address each finding (e.g., `/fix`, `/implement`)

7. Write findings to a spec file using the `review-` prefix per the `specify-*` conventions in AGENTS.md.
