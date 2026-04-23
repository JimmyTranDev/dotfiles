---
name: specify-optimize
description: Profile code for performance bottlenecks and report optimization opportunities without making changes and write spec to `spec/`
---

Usage: /specify-optimize [scope or description]

Profile the specified code for performance bottlenecks and report optimization opportunities without applying any changes. Write all findings to a spec file.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files, functions, or areas, focus analysis there
   - If the user describes a performance symptom (slow load, high memory, timeout), locate the relevant code
   - If no scope is given, identify the most performance-critical paths in the project

2. Load all applicable skills in parallel (**code-follower** and optionally **code-simplifier**), then profile and identify bottlenecks:
   - Analyze algorithmic complexity — look for O(n^2) or worse in hot paths
   - Check for unnecessary re-renders, re-computations, or redundant work
   - Identify expensive I/O operations that could be batched, cached, or parallelized
   - Look for memory leaks, large allocations, or missing cleanup
   - Check bundle size impact if working on frontend code

3. Prioritize the findings:
   - Rank by expected impact (latency reduction, memory savings, throughput gain)
   - Estimate effort for each optimization
   - Focus on the highest impact-to-effort ratio improvements first

4. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - For each bottleneck, include the file path and line number, the performance issue description, estimated impact, effort level, and a concrete suggestion showing what the optimized code would look like
   - Group findings by category (algorithmic, I/O, rendering, memory, bundle size)
   - Within each category, rank by impact (high first)

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **optimizer**: Primary agent — profiles bottlenecks and identifies optimization opportunities
   - **reviewer**: Verify optimization suggestions are correct and won't break behavior

6. Write findings to a spec file:
   - Create the `spec/` directory if it doesn't exist
   - Choose the filename: use the `optimize-` prefix followed by a descriptive kebab-case name based on the scope or key findings (e.g., `spec/optimize-api-endpoints.md`, `spec/optimize-database-queries.md`)
   - If a file with the chosen name already exists, append a numeric suffix (e.g., `spec/optimize-api-endpoints-2.md`)
   - Write all findings to the file: grouped by category, ranked by impact, with file location, description, estimated impact, effort level, and suggested optimization for each item
   - Print a brief summary to chat: the spec file path, total findings count, and the top 3 highest-impact items
