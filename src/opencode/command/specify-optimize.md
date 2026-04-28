---
name: specify-optimize
description: Profile code for performance bottlenecks and report optimization opportunities without making changes and write spec to `spec/`
---

Usage: /specify-optimize [scope or description]

Profile the specified code for performance bottlenecks and report optimization opportunities without applying any changes. Write all findings to a spec file.

$ARGUMENTS

1. Load skills: **code-follower** and optionally **code-simplifier**. Profile and identify bottlenecks:
   - Analyze algorithmic complexity — look for O(n^2) or worse in hot paths
   - Check for unnecessary re-renders, re-computations, or redundant work
   - Identify expensive I/O operations that could be batched, cached, or parallelized
   - Look for memory leaks, large allocations, or missing cleanup
   - Check bundle size impact if working on frontend code

2. Prioritize the findings:
   - Rank by expected impact (latency reduction, memory savings, throughput gain)
   - Estimate effort for each optimization
   - Focus on the highest impact-to-effort ratio improvements first

3. Present the analysis:
   - For each bottleneck, include the file path and line number, the performance issue description, estimated impact, effort level, and a concrete suggestion showing what the optimized code would look like
   - Group findings by category (algorithmic, I/O, rendering, memory, bundle size)
   - Within each category, rank by impact (high first)

4. Launch agents in parallel:
   - **optimizer**: Primary agent — profiles bottlenecks and identifies optimization opportunities
   - **reviewer**: Verify optimization suggestions are correct and won't break behavior

5. Write findings to a spec file using the `optimize-` prefix per the `specify-*` conventions in AGENTS.md.
