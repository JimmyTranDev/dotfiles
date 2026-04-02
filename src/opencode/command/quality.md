---
name: quality
description: Restructure code for better quality, readability, and maintainability without changing behavior
---

Usage: /quality [scope or description]

Refactor the specified code to improve its internal quality — structure, readability, and maintainability — without changing user-facing behavior.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or pattern, search the codebase to locate the relevant code
   - Run tests or build commands if available to establish a working baseline before making changes

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
   - For each opportunity, explain the current code smell, which principle it violates (DRY, KISS, YAGNI, SRP, etc.), and what the refactored version looks like

4. Apply the refactoring:
   - Make changes incrementally, verifying each refactor preserves existing behavior exactly
   - Preserve existing conventions and patterns — restructure within the established style, not against it
   - Focus purely on internal code quality (use `/ux` for user-facing enhancements)

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **optimizer**: Use if performance-sensitive code is identified during refactoring
   - **reviewer** + **tester**: Launch in parallel after refactoring is complete — reviewer verifies correctness and code quality while tester runs tests and adds coverage for refactored code

6. After refactoring:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize each refactoring applied: what the code smell was, which principle was applied, and how it improved the codebase
   - List any follow-up refactoring opportunities that were out of scope but worth noting

7. Persist follow-up items to `IMPROVEMENTS.md` in the project root:
   - Write all follow-up refactoring opportunities to `IMPROVEMENTS.md` in the project root
   - If the file already exists, append a new section with a timestamp header
   - Include each item's description, estimated impact, and which principle or agent applies
