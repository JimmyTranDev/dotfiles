---
name: improve-consolidate
---

Usage: /improve-consolidate [scope or description]

Find and merge over-separated code — thin files, pass-through layers, single-use wrappers, and fragmented configs — to reduce indirection and cognitive load.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a pattern or area, search the codebase to locate the relevant code
   - If no scope is given, scan the project for over-separation smells

2. Load all applicable skills in parallel (**consolidator**, **follower**, and optionally **simplifier**, **deduplicator**, **structure**, **pragmatic-programmer**), then identify over-separation smells:
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
   - Verify the merged result stays under 200 lines
   - Check that merging does not combine genuinely different concerns (types vs. logic vs. constants)
   - Check that files don't have different change frequencies (stable types vs. volatile logic)

4. Prioritize and present findings:
   - Rank consolidation opportunities by impact (high, medium, low) considering indirection reduction, navigation improvement, and risk
   - For each opportunity, explain the smell, what will be merged, and the resulting structure
   - Ask the user which consolidations to apply using the question tool with `multiple: true`

5. Apply the consolidations:
   - Merge incrementally, verifying each consolidation preserves existing behavior
   - Update all import consumers to use the new locations
   - Remove dead files and empty directories
   - Preserve existing codebase conventions and patterns

6. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer** + **tester**: Launch in parallel after consolidation is complete — reviewer verifies correctness and import integrity while tester runs tests to confirm no regressions

7. After consolidation:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize each consolidation applied: the smell, what was merged, and the resulting file structure
   - List any follow-up consolidation opportunities that were out of scope
