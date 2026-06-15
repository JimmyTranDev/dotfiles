---
name: specify-devtools
description: Specify skill for developer tooling analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`devtools-`

## Skills to Load

- **tool-eslint-config**: ESLint flat config setup and rule tiers
- **code-conventions**: Coding conventions and module structure
- **git-workflows**: Branch naming, commit conventions, PR workflows
- **meta-shell-scripting**: Shell scripting conventions
- **git-gitignore**: .gitignore organization and pattern rules
- **test**: Testing patterns (optional)
- **security-npm-vulnerabilities**: npm audit workflow (optional)
- **ts-total-typescript**: TypeScript patterns (optional)

## Agents to Launch

- **reviewer**: Analyze tooling configs for correctness issues and inconsistencies
- **auditor**: Check for security gaps in CI/CD, missing secret scanning, exposed credentials

## Analysis Categories

- **Linting and formatting**: ESLint config completeness, Prettier setup, rule coverage gaps, conflicting rules, missing plugins, typed linting enablement
- **Type checking**: TypeScript strictness level, missing strict flags, `any` escape hatches, path aliases, project references for monorepos
- **Git hooks**: Pre-commit hooks (lint-staged, husky, lefthook), commit message validation, secret detection, missing hooks
- **CI/CD pipeline**: Missing workflow steps (lint, test, typecheck, build, security scan), caching strategy, matrix testing, deployment automation gaps
- **Scripts**: package.json scripts completeness (dev, build, lint, test, typecheck, clean), missing convenience scripts, inconsistent naming, missing parallelization
- **Editor and IDE config**: Missing .editorconfig, VS Code settings/extensions, missing debug launch configs
- **Dependency management**: Lockfile hygiene, outdated package manager, missing engine constraints, missing renovate/dependabot config, supply chain protections
- **Git configuration**: .gitignore completeness, .gitattributes for line endings, branch protection gaps
- **Documentation as tooling**: Missing CONTRIBUTING.md, missing ADRs, missing onboarding scripts
- **Monorepo tooling**: Workspace config, shared configs, dependency hoisting, task orchestration (turbo, nx, lerna)

## Severity Classification

Rank by impact-to-effort ratio:
- **High impact / Low effort**: Quick wins (missing .editorconfig, incomplete scripts)
- **High impact / Medium effort**: CI gaps, missing hooks
- **Medium impact**: Tooling inconsistencies
- **Low impact**: Nice-to-have polish

## Scope Overrides

None — uses default scope detection.
