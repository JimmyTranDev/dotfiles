---
name: specify-optimize
description: Specify skill for performance optimization analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`optimize-`

## Skills to Load

- **code-follower**: Match existing codebase conventions
- **code-simplifier**: Complexity reduction strategies (optional)

## Agents to Launch

- **optimizer**: Profile bottlenecks and identify optimization opportunities
- **reviewer**: Verify optimization suggestions are correct and won't break behavior

## Analysis Categories

- **Algorithmic complexity**: O(n^2) or worse in hot paths
- **Redundant computation**: Unnecessary re-renders, re-computations, or redundant work
- **I/O efficiency**: Expensive I/O operations that could be batched, cached, or parallelized
- **Memory**: Memory leaks, large allocations, or missing cleanup
- **Bundle size**: Frontend bundle size impact (if applicable)

### Presentation Format

For each bottleneck:
- File path and line number
- Performance issue description
- Estimated impact (latency reduction, memory savings, throughput gain)
- Effort level
- Concrete suggestion showing what optimized code would look like

Group by category (algorithmic, I/O, rendering, memory, bundle size), rank by impact within each.

## Severity Classification

Rank by expected impact:
- **High**: Measurable latency/memory improvement in hot paths
- **Medium**: Improvement in less-critical paths
- **Low**: Micro-optimizations with minimal real-world impact

## Scope Overrides

None — uses default scope detection.
