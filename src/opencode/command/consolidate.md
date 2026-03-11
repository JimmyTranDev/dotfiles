---
name: consolidate
description: Find and merge over-separated code by collapsing unnecessary files, layers, and abstractions
---

Usage: /consolidate [scope or description]

Scan the specified code for over-separation and consolidate things that don't need to be separate.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a pattern or area, search the codebase to locate it
   - If no scope is given, analyze the current working directory recursively

2. Load the **consolidator** and **convention-matcher** skills in parallel, then scan for over-separation smells — use the decision tree and smell table from the **consolidator** skill:
   - Thin files (< 20 lines of logic)
   - Single-use wrappers and trivial abstractions
   - Pass-through layers that add no transformation
   - One-item directories
   - Proxy components that just forward props
   - Fragmented configs that belong together
   - Premature splits where complexity doesn't warrant separation

3. For each finding, report:
   - What is over-separated and why
   - The proposed consolidation (which files merge, which abstractions inline, which layers collapse)
   - The estimated result (line count, file count after merge)

4. Ask the user to confirm before applying changes

5. Apply the consolidations:
   - Merge file contents, preserving all logic
   - Inline trivial abstractions at their call sites
   - Remove pass-through layers and connect callers directly
   - Delete empty files and directories after merging
   - Update all imports across the codebase to reflect new locations

6. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel after consolidation):
   - **reviewer**: Verify merged code is correct and no behavior changed
   - **tester**: Run tests to confirm nothing broke, add coverage if gaps exist

7. After consolidation:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize what was merged and the reduction in file/line count

Important:
- Never merge files that represent genuinely different concerns
- Never create files over 200 lines by merging — split the consolidation if needed
- Preserve all existing behavior — consolidation is structural, not functional
- Do not inline abstractions that communicate domain intent or have multiple callers
- Do not remove layers that add validation, transformation, or enforce boundaries
