---
name: quality
description: Analyze code for quality issues and report refactoring opportunities without making changes
---

Usage: /quality [scope or description]

Analyze the specified code for internal quality issues — structure, readability, and maintainability — and report refactoring opportunities without applying any changes.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or pattern, search the codebase to locate the relevant code
   - If no scope is given, analyze the full codebase

2. Load all applicable skills in parallel (**follower**, **simplifier**, **deduplicator**, **pragmatic-programmer**, and optionally **consolidator**, **logic-checker**, **total-typescript**, **eslint-config**, and **shell-scripting**), then analyze the code for internal quality issues across these categories:
   - **Naming clarity**: vague variable/function names, inconsistent naming conventions, misleading identifiers
   - **Function design**: functions doing too much, unclear responsibilities, deeply nested logic, high cyclomatic complexity
   - **Duplication**: repeated patterns, copy-pasted logic, similar implementations that should be unified via DRY
   - **Over-engineering**: premature abstractions, unnecessary indirection, wrapper functions that add no value — apply KISS and YAGNI
   - **Type safety**: loose types, `any` usage, unsafe casts, missing discriminated unions, overly broad generics
   - **Dead code**: unused exports, unreachable branches, deprecated patterns still in place, vestigial parameters
   - **Module structure**: tight coupling, poor cohesion, circular dependencies, barrel file bloat, unclear dependency direction
   - **Architecture**: mixed abstraction levels, leaky abstractions, god objects, violation of single responsibility

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
   - Suggest which `/command` to run to address each finding (e.g., `/implement`, `/fix`, `/consolidate`)

7. Persist findings to `IMPROVEMENTS.md` in the project root:
   - Write all refactoring opportunities to `IMPROVEMENTS.md` in the project root
   - If the file already exists, append a new section with a timestamp header
   - Include each item's file location, description, estimated impact, violated principle, and suggested `/command`
