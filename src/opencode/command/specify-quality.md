---
name: specify-quality
description: Analyze code for quality issues, simplification opportunities, and refactoring candidates and write spec to `spec/`
---

Usage: /specify-quality [scope or description]

Analyze the specified code for internal quality issues — structure, readability, maintainability, unnecessary complexity, and code smells — and report refactoring opportunities without applying any changes. Write all findings to a spec file.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or pattern, search the codebase to locate the relevant code
   - If no scope is given, analyze the full codebase
   - Read all target files and their direct dependents (callers, importers)
   - Map the public API surface — what do consumers actually use?

2. Load all applicable skills in parallel (**code-follower**, **code-simplifier**, **code-deduplicator**, **code-conventions**, **strategy-pragmatic-programmer**, and optionally **code-consolidator**, **code-logic-checker**, **ts-total-typescript**, **tool-eslint-config**, **meta-shell-scripting**), then analyze the code across these categories:
   - **Naming clarity**: vague variable/function names, inconsistent naming conventions, misleading identifiers
   - **Function design**: functions doing too much, unclear responsibilities, deeply nested logic, high cyclomatic complexity
   - **Duplication**: repeated patterns, copy-pasted logic, similar implementations that should be unified via DRY
   - **Over-engineering**: premature abstractions, unnecessary indirection, wrapper functions that add no value — apply KISS and YAGNI
   - **Type safety**: loose types, `any` usage, unsafe casts, missing discriminated unions, overly broad generics
   - **Dead code**: unused exports, unreachable branches, deprecated patterns still in place, vestigial parameters
   - **Module structure**: tight coupling, poor cohesion, circular dependencies, barrel file bloat, unclear dependency direction
   - **Architecture**: mixed abstraction levels, leaky abstractions, god objects, violation of single responsibility
   - **Simplification**: deeply nested conditionals that could use early returns, imperative loops replaceable with declarative transforms, state management with unnecessary intermediaries, trivial single-use abstractions that add indirection

3. Prioritize the findings:
   - Rank refactoring opportunities by code quality impact (high, medium, low) considering readability gain, maintenance burden reduction, and risk of change
   - For each opportunity, explain the current code smell, which principle it violates (DRY, KISS, YAGNI, SRP, etc.), and what the refactored version would look like

4. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - For each finding, include the file path and line number, the code smell description, the violated principle, and a concrete suggestion showing what the refactored code would look like
   - Group findings by category from step 2
   - Within each category, rank by impact (high first)

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Analyze code for correctness issues, design problems, and maintainability concerns
   - **auditor**: Scan for security vulnerabilities that overlap with quality issues

6. Summarize the analysis:
   - Report total findings by category and severity
   - Highlight the top 3-5 highest-impact refactoring opportunities
   - Suggest which `/command` to run to address each finding (e.g., `/implement`, `/fix`)

7. Write findings to a spec file:
   - Create the `spec/` directory if it doesn't exist
   - Choose the filename: use the `quality-` prefix followed by a descriptive kebab-case name based on the scope or key findings (e.g., `spec/quality-auth-module.md`, `spec/quality-api-layer-complexity.md`)
   - If a file with the chosen name already exists, append a numeric suffix (e.g., `spec/quality-auth-module-2.md`)
   - Write all findings to the file in the same structured format: grouped by category, ranked by impact, with file location, description, estimated impact, violated principle, and suggested `/command` for each item
   - Print a brief summary to chat: the spec file path, total findings count, and the top 3 highest-impact items

8. After completing the analysis, load the **meta-skill-learnings** skill and improve any relevant skills with reusable patterns, gotchas, or anti-patterns discovered during the analysis.
