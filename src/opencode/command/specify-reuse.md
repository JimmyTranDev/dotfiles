---
name: specify-reuse
description: Find duplicated patterns, over-separated code, missed abstractions, and reuse opportunities and write spec to `spec/`
---

Usage: /specify-reuse [scope or description]

Scan the codebase for duplicated patterns, over-separated code, missed abstractions, and reuse opportunities — report findings without applying any changes. Write all findings to a spec file.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a pattern or area, search the codebase to locate the relevant code
   - If no scope is given, scan the full codebase

2. Load all applicable skills in parallel (**code-deduplicator**, **code-consolidator**, **code-follower**, and optionally **code-simplifier**, **strategy-pragmatic-programmer**, **meta-structure**), then scan across these categories:

   **Duplication (code that should be shared):**
   - **Exact duplicates**: identical or near-identical code blocks appearing in multiple files
   - **Structural duplicates**: different variable names but same logic shape, control flow, or algorithm
   - **Similar patterns**: repeated sequences of operations (fetch-then-transform, validate-then-save, try-catch-log) that could be a shared utility
   - **Repeated type definitions**: identical or overlapping interfaces, types, or schemas defined in multiple places
   - **Copy-pasted components**: UI components with the same structure but minor prop or style differences that could be parameterized
   - **Reimplemented utilities**: custom code that duplicates functionality already available in the project's dependencies or standard library

   **Abstraction (code that needs a named concept):**
   - **Missing abstractions**: multiple call sites performing the same multi-step workflow inline instead of through a named function, hook, or class
   - **Ungeneralized solutions**: code that handles one specific case but could be parameterized to cover related cases already handled elsewhere
   - **Cross-cutting concerns**: logging, error handling, auth checks, or validation repeated ad-hoc instead of handled by a shared middleware, decorator, or wrapper
   - **Parallel hierarchies**: mirrored file or class structures that change together and could share a base

   **Over-separation (code that should be merged):**
   - **Thin files**: files with < 20 lines of actual logic that could merge into a related file
   - **Single-use wrappers**: functions or components that wrap another with no added logic
   - **Pass-through layers**: modules that forward calls without transformation
   - **Fragmented configs**: related settings scattered across multiple files
   - **One-item directories**: directories containing a single file that could move up a level
   - **Premature splits**: features split into files before complexity warrants it
   - **Trivial abstractions**: helpers called once with 1-3 line bodies

3. For each finding, document:
   - All locations where the pattern appears (file paths and line numbers)
   - The duplicated code, over-separated structure, or missing abstraction with a representative example
   - A concrete suggestion: the shared abstraction (where it would live, its API, how call sites would use it) or the merge target (what files combine, resulting structure)
   - Estimated impact: lines saved, maintenance burden reduced, consistency gained
   - Risk level: low (mechanical extraction/merge), medium (needs minor refactoring), high (requires interface changes)

4. Evaluate consolidation candidates using the decision tree:
   - Confirm the pieces are not independently consumed or tested by different parts of the codebase
   - Verify the merged result would stay under 200 lines
   - Check that merging would not combine genuinely different concerns (types vs. logic vs. constants)
   - Check that files don't have different change frequencies (stable types vs. volatile logic)

5. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - Group findings by the three top-level categories (Duplication, Abstraction, Over-separation)
   - Within each category, rank by number of occurrences and estimated impact (high first)
   - Highlight the top 5 highest-impact opportunities across all categories

6. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Verify extraction and merge suggestions are correct and won't break existing behavior

7. Summarize the analysis:
   - Report total findings by category and estimated lines that could be deduplicated or consolidated
   - Highlight the top 3-5 highest-impact opportunities
   - Suggest which `/command` to run to address each finding (e.g., `/implement` to extract a utility or merge files)

8. Write findings to a spec file:
   - Create the `spec/` directory if it doesn't exist
   - Choose the filename: use the `reuse-` prefix followed by a descriptive kebab-case name based on the scope or key findings (e.g., `spec/reuse-api-handlers.md`, `spec/reuse-validation-logic.md`)
   - If a file with the chosen name already exists, append a numeric suffix (e.g., `spec/reuse-api-handlers-2.md`)
   - Write all findings to the file: grouped by category, ranked by impact, with all locations, representative code, suggested abstraction or merge, estimated impact, and risk level for each item
   - Print a brief summary to chat: the spec file path, total findings count, estimated deduplication potential, and the top 3 highest-impact items
