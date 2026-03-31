---
name: optimize
description: Profile and optimize code for better performance with measurable improvements
---

Usage: /optimize [scope or description]

Profile the specified code for performance bottlenecks and apply optimizations with measurable improvements.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files, functions, or areas, focus optimization there
   - If the user describes a performance symptom (slow load, high memory, timeout), locate the relevant code
   - If no scope is given, identify the most performance-critical paths in the project

2. Profile and identify bottlenecks:
   - Analyze algorithmic complexity — look for O(n^2) or worse in hot paths
   - Check for unnecessary re-renders, re-computations, or redundant work
   - Identify expensive I/O operations that could be batched, cached, or parallelized
   - Look for memory leaks, large allocations, or missing cleanup
   - Check bundle size impact if working on frontend code

3. Prioritize optimizations:
   - Rank by expected impact (latency reduction, memory savings, throughput gain)
   - Estimate effort for each optimization
   - Focus on the highest impact-to-effort ratio improvements first

4. Apply optimizations:
   - Make changes incrementally, measuring before and after where possible
   - Preserve existing behavior — optimizations must not change functionality
   - Follow existing codebase conventions and patterns

5. Verify:
   - Run tests to confirm no regressions
   - Run benchmarks or profiling tools if available
   - Report measurable improvements (time, memory, bundle size)

6. Ask the user which follow-up optimizations to pursue using the question tool with `multiple: true`, then implement the selected items

7. Load applicable skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Skills to load (load all applicable skills in a single parallel batch):
   - **follower**: Always load to match existing codebase conventions

   Agents to delegate to:
   - **optimizer**: Primary agent — profiles bottlenecks and implements measurable improvements
   - **tester**: Launch after optimizations to verify no regressions
   - **reviewer**: Launch in parallel with tester to verify optimization correctness
