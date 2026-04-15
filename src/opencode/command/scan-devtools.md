---
name: scan-devtools
description: Analyze developer tooling setup and identify improvements to linting, formatting, CI/CD, scripts, git hooks, and DX
---

Usage: /scan-devtools [scope or description]

Analyze the project's developer tooling configuration and identify gaps, misconfigurations, and improvement opportunities across linting, formatting, type checking, CI/CD, git hooks, scripts, editor config, and overall developer experience.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key config files to understand the tech stack
   - Run `git log --oneline -30` to understand recent development direction
   - Read package.json (or equivalent) for scripts, dependencies, and tooling configuration
   - Check for existing CI/CD config (.github/workflows, .gitlab-ci.yml, Jenkinsfile, etc.)

2. If the user specifies a scope or focus area, narrow analysis to that. Otherwise analyze the full tooling setup.

3. Load all applicable skills in parallel (**tool-eslint-config**, **code-conventions**, **git-workflows**, **meta-shell-scripting**, **git-gitignore**, and optionally **test**, **security-npm-vulnerabilities**, **ts-total-typescript**).

4. Analyze the project's developer tooling across these categories (only include categories that are relevant):
   - **Linting and formatting**: ESLint config completeness, Prettier or formatting tool setup, rule coverage gaps, conflicting rules, missing plugins for the tech stack, typed linting enablement
   - **Type checking**: TypeScript strictness level, missing strict flags, `any` escape hatches in config, path aliases, project references for monorepos
   - **Git hooks**: Pre-commit hooks (lint-staged, husky, lefthook), commit message validation (commitlint), secret detection (TruffleHog), missing hooks that would prevent bad commits
   - **CI/CD pipeline**: Missing or incomplete workflow steps (lint, test, typecheck, build, security scan), caching strategy, matrix testing, deployment automation gaps
   - **Scripts**: package.json scripts completeness (dev, build, lint, test, typecheck, clean), missing convenience scripts, inconsistent script naming, missing parallelization (concurrently, turbo)
   - **Editor and IDE config**: Missing .editorconfig, VS Code settings/extensions recommendations, missing debug launch configs
   - **Dependency management**: Lockfile hygiene, outdated package manager version, missing engine constraints, missing renovate/dependabot config, supply chain protections
   - **Git configuration**: .gitignore completeness, .gitattributes for line endings and merge drivers, branch protection gaps
   - **Documentation as tooling**: Missing CONTRIBUTING.md, missing architecture decision records, missing onboarding scripts or setup guides
   - **Monorepo tooling**: If applicable — workspace config, shared configs, dependency hoisting, task orchestration (turbo, nx, lerna)

5. For each finding:
   - Give it a short, clear name
   - Describe the gap or misconfiguration and why it matters for developer productivity
   - Estimate effort (small, medium, large) and impact (high, medium, low)
   - Include file paths and line numbers where applicable
   - Suggest which `/command` to run to address it (e.g., `/implement`, `/fix`, `/pr-audit`)

6. Delegate to specialized agents where applicable — launch independent agents in parallel:
   - **reviewer**: Analyze tooling configs for correctness issues and inconsistencies
   - **auditor**: Check for security gaps in CI/CD, missing secret scanning, exposed credentials in configs

7. Present findings:
   - Do NOT apply any changes — this command is analysis-only
   - Group by category from step 4
   - Within each category, rank by impact-to-effort ratio (quick wins first)
   - Highlight the top 3-5 highest-priority improvements across all categories
   - Flag any issues that could be fixed immediately with existing `/commands`

8. Output findings directly in chat as the final response. If the user specifies an output destination (file path, format, etc.), write there instead.
   - When writing to a file, append a new section with a timestamp header (create the file if it doesn't exist)
   - Include each item's file location, description, estimated effort/impact, and suggested `/command`
