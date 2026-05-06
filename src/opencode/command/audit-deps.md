---
name: audit-deps
description: Analyze dependencies for outdated packages, security issues, and unused exports
---

Usage: /audit-deps [scope]

Analyze the project's dependencies for outdated versions, known security vulnerabilities, and unused packages.

$ARGUMENTS

1. Load the **security-npm-vulnerabilities** and **tool-knip** skills
2. Run `detect-stack.sh` to identify the package manager and project type
3. If no package manager is detected, notify the user and stop
4. If scope is provided, focus analysis on those packages or directories
5. Run `check-deps.sh` to perform the outdated check and security audit in one step
6. Optionally run knip to detect unused dependencies: `npx knip --include unlisted,unused`
7. Compile results into a summary table with columns: Package, Current, Latest, Severity, Issue
8. Categorize findings by severity (critical, high, moderate, low)
9. Output the summary table and a prioritized list of recommended actions

Constraints:
- Do not modify any files — this is analysis only
- If a command fails (e.g., audit not supported), skip it and note the limitation
- Report total counts per severity level at the top of the output
