---
name: specify-review
description: Review codebase for bugs, design issues, and correctness problems without making changes and write spec to `spec/review/`
---

Usage: /specify-review [scope or description]

Analyze the specified code for bugs, design issues, and correctness problems — report findings and write them to a spec file.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a feature or area, search the codebase to locate the relevant code
   - If no scope is given, review the current branch's diff against the base branch:
     - Check if `develop` branch exists locally or as `origin/develop` — if so, use it as the base; otherwise fall back to `main` (or `origin/main`)
     - Run in parallel: `git diff <base-branch>...HEAD` and `git log --oneline <base-branch>..HEAD`
     - If no commits exist on the branch beyond the base, notify the user and stop

2. Load all applicable skills in parallel (**code-follower**, **code-logic-checker**, **code-soundness**, and optionally **code-conventions**, **strategy-pragmatic-programmer**, **ts-total-typescript**, **meta-shell-scripting**), then analyze the code for issues across these categories:
   - **Correctness**: Logic errors, wrong return values, incorrect conditionals, missing return paths, flawed comparisons
   - **Error handling**: Swallowed errors, missing try/catch, catch-all handlers that hide failures, unhandled promise rejections, missing error propagation
   - **Edge cases**: Null/undefined access, empty collections, boundary values, zero-length strings, negative numbers, overflow
   - **Race conditions**: Async ordering bugs, missing awaits, shared mutable state, stale closures, fire-and-forget calls that should be awaited
   - **API contracts**: Mismatched types between caller and callee, undocumented assumptions about input shape, missing validation
   - **State management**: Impossible states, missing state transitions, stale state reads, derived state that can desync
   - **Security**: Injection vectors, auth bypasses, sensitive data exposure, missing input sanitization

3. For each finding:
   - Give it a short, clear name
   - Include the file path and line number
   - Describe the bug or issue and its potential impact in 1-2 sentences
   - Classify severity (critical, major, minor, warning)
   - Suggest a concrete fix

4. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - Group findings by category from step 2
   - Within each category, rank by severity (critical first)
   - Highlight the top 3-5 most critical findings across all categories

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Catches bugs, design issues, and provides actionable feedback
   - **auditor**: Scans for security vulnerabilities and exploitable bugs
   - **optimizer**: Identifies performance concerns if the code introduces potentially expensive operations

6. Summarize the analysis:
   - Report total findings by category and severity
   - Highlight the most critical items that need immediate attention
   - Suggest which `/command` to run to address each finding (e.g., `/fix`, `/implement`, `/improve-security`)

7. Write findings to a spec file:
   - Create the `spec/review/` directory if it doesn't exist
   - Choose the filename: if the user provided a scope description, use it in kebab-case (e.g., `spec/review/auth-module.md`); otherwise use today's date (e.g., `spec/review/2026-04-23.md`)
   - If a file with the chosen name already exists, append a timestamp suffix (e.g., `spec/review/auth-module-1682300000.md`)
   - Write all findings to the file using the same structured format: grouped by category, ranked by severity, with file location, severity, description, and suggested fix for each item
   - Print a brief summary to chat: the spec file path, total findings count, and the top 3 most critical items
