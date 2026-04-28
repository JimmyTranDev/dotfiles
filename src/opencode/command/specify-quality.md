---
name: specify-quality
description: Analyze code for quality issues, simplification opportunities, and refactoring candidates and write spec to `spec/`
---

Usage: /specify-quality [scope or description]

Analyze the specified code for internal quality issues — structure, readability, maintainability, unnecessary complexity, and code smells — and report refactoring opportunities without applying any changes. Write all findings to a spec file.

$ARGUMENTS

1. Load skills: **code-follower**, **code-simplifier**, **code-deduplicator**, **code-conventions**, **strategy-pragmatic-programmer**, and optionally **code-consolidator**, **code-logic-checker**, **ts-total-typescript**, **tool-eslint-config**, **meta-shell-scripting**. Read all target files and their direct dependents (callers, importers). Map the public API surface — what do consumers actually use? Analyze the code across these categories:
   - **Naming clarity**: vague variable/function names, inconsistent naming conventions, misleading identifiers
   - **Function design**: functions doing too much, unclear responsibilities, deeply nested logic, high cyclomatic complexity
   - **Duplication**: repeated patterns, copy-pasted logic, similar implementations that should be unified via DRY
   - **Over-engineering**: premature abstractions, unnecessary indirection, wrapper functions that add no value — apply KISS and YAGNI
   - **Type safety**: loose types, `any` usage, unsafe casts, missing discriminated unions, overly broad generics
   - **Dead code**: unused exports, unreachable branches, deprecated patterns still in place, vestigial parameters
   - **Module structure**: tight coupling, poor cohesion, circular dependencies, barrel file bloat, unclear dependency direction
   - **Architecture**: mixed abstraction levels, leaky abstractions, god objects, violation of single responsibility
   - **Simplification**: deeply nested conditionals that could use early returns, imperative loops replaceable with declarative transforms, state management with unnecessary intermediaries, trivial single-use abstractions that add indirection

2. Prioritize the findings:
   - Rank refactoring opportunities by code quality impact (high, medium, low) considering readability gain, maintenance burden reduction, and risk of change
   - For each opportunity, explain the current code smell, which principle it violates (DRY, KISS, YAGNI, SRP, etc.), and what the refactored version would look like

3. Present the analysis:
   - For each finding, include the file path and line number, the code smell description, the violated principle, and a concrete suggestion showing what the refactored code would look like
   - Group findings by category from step 1
   - Within each category, rank by impact (high first)

4. Launch agents in parallel:
   - **reviewer**: Analyze code for correctness issues, design problems, and maintainability concerns
   - **auditor**: Scan for security vulnerabilities that overlap with quality issues

5. Summarize the analysis:
   - Report total findings by category and severity
   - Highlight the top 3-5 highest-impact refactoring opportunities
   - Suggest which `/command` to run to address each finding (e.g., `/implement`, `/fix`)

6. Write findings to a spec file using the `quality-` prefix per the `specify-*` conventions in AGENTS.md.
