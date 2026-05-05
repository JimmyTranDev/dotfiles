---
name: dependency
description: Analyze dependencies for outdated packages, security issues, and unused exports
---

Usage: /dependency-check [scope]

Analyze the project's dependencies for outdated versions, known security vulnerabilities, and unused packages.

$ARGUMENTS

1. Load the **security-npm-vulnerabilities** and **tool-knip** skills
2. Detect the package manager by checking for lock files (package-lock.json, yarn.lock, pnpm-lock.yaml, bun.lockb)
3. If no package manager is detected, notify the user and stop
4. If scope is provided, focus analysis on those packages or directories
5. Run the outdated check:
   - npm: `npm outdated --json`
   - yarn: `yarn outdated --json`
   - pnpm: `pnpm outdated --json`
6. Run the security audit:
   - npm: `npm audit --json`
   - yarn: `yarn audit --json`
   - pnpm: `pnpm audit --json`
7. Optionally run knip to detect unused dependencies: `npx knip --include unlisted,unused`
8. Compile results into a summary table with columns: Package, Current, Latest, Severity, Issue
9. Categorize findings by severity (critical, high, moderate, low)
10. Output the summary table and a prioritized list of recommended actions

Constraints:
- Do not modify any files — this is analysis only
- If a command fails (e.g., audit not supported), skip it and note the limitation
- Report total counts per severity level at the top of the output
