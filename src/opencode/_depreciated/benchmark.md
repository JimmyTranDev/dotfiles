---
name: benchmark
description: Run and compare performance benchmarks with before/after reporting
---

Usage: /benchmark [command or file]

Run a performance benchmark and compare results against previous runs to detect regressions.

$ARGUMENTS

1. Parse the benchmark target from arguments — either a shell command to execute or a benchmark file to run
2. If no target is provided, look for common benchmark configurations (bench/, *.bench.ts, vitest.config with bench, package.json bench script)
3. If no benchmark target can be determined, notify the user and stop
4. Run the benchmark command and capture output including:
   - Execution time
   - Memory usage (if available)
   - Ops/second (if available)
   - Any other metrics reported
5. Check if a previous benchmark result exists (look for .benchmark-results.json or similar in the project)
6. If previous results exist, compute the diff:
   - Calculate percentage change for each metric
   - Flag regressions (>5% slower or >10% more memory)
7. If regressions are detected, delegate to the **optimizer** agent with the regression details and relevant source files
8. Output a results table with columns: Metric, Previous, Current, Change, Status (✓/✗)
9. If no previous results exist, output current results and save as baseline

Constraints:
- Do not modify source files — only run benchmarks and report
- If the benchmark command fails, report the error output and stop
- Timeout benchmark runs after 5 minutes
