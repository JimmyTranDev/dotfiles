---
name: specify-consolidate
description: Analyze code for over-separation smells and report consolidation opportunities without making changes and write spec to `spec/consolidate/`
---

Usage: /specify-consolidate [scope or description]

Find over-separated code — thin files, pass-through layers, single-use wrappers, and fragmented configs — and report consolidation opportunities without applying any changes. Write all findings to a spec file.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a pattern or area, search the codebase to locate the relevant code
   - If no scope is given, scan the project for over-separation smells

2. Load all applicable skills in parallel (**code-consolidator**, **code-follower**, and optionally **code-simplifier**, **code-deduplicator**, **meta-structure**, **strategy-pragmatic-programmer**), then identify over-separation smells:
   - **Thin files**: files with < 20 lines of actual logic that could merge into a related file
   - **Single-use wrappers**: functions or components that wrap another with no added logic
   - **Pass-through layers**: modules that forward calls without transformation
   - **Fragmented configs**: related settings scattered across multiple files
   - **One-item directories**: directories containing a single file that could move up a level
   - **Premature splits**: features split into files before complexity warrants it
   - **Proxy components**: components rendering another with identical props
   - **Trivial abstractions**: helpers called once with 1-3 line bodies

3. Evaluate each candidate using the consolidation decision tree:
   - Confirm the pieces are not independently consumed or tested by different parts of the codebase
   - Verify the merged result would stay under 200 lines
   - Check that merging would not combine genuinely different concerns (types vs. logic vs. constants)
   - Check that files don't have different change frequencies (stable types vs. volatile logic)

4. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - Rank consolidation opportunities by impact (high, medium, low) considering indirection reduction, navigation improvement, and risk
   - For each opportunity, explain the smell, what would be merged, and the resulting structure

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Analyze code structure for correctness of consolidation recommendations

6. Write findings to a spec file:
   - Create the `spec/consolidate/` directory if it doesn't exist
   - Choose the filename: if the user provided a scope description, convert it to kebab-case and use it as the filename (e.g., `auth-module.md`); otherwise use a timestamp (`YYYY-MM-DDTHH-MM-SS.md`)
   - If a file with the chosen name already exists, append a timestamp suffix before the extension
   - Write all findings to the file: grouped by smell type, ranked by impact, with file locations, descriptions, proposed merged structure, and estimated impact for each item
   - Print a brief summary to chat: the spec file path, total findings count, and the top 3 highest-impact items
