# Utility Scripts for OpenCode AI Workflows

## Overview

The `etc/scripts/ai/` directory contains 4 scripts that OpenCode agents call during tasks (check-deps, project-info, run-tests, fms-export-new). Many OpenCode commands repeat the same operations via AI tool calls — detecting the tech stack, finding the base branch, installing dependencies, running linters, scaffolding spec files. Extracting these into reusable shell scripts would reduce token usage, improve consistency, and make the operations available outside of OpenCode.

## Architecture

All new scripts go in `etc/scripts/ai/`. They follow the established pattern: `set -e`, source `common/logging.sh`, function-based structure, `SCRIPT_DIR` detection, `main "$@"` entry point. OpenCode agents call these via the Bash tool. Scripts output structured text (or JSON where useful) that agents can parse.

## Data flow

1. OpenCode command starts (e.g., `/specify`, `/pr`, `/fix-checks`)
2. Agent calls `etc/scripts/ai/<script>.sh` via Bash tool
3. Script auto-detects project context and performs the operation
4. Script outputs results to stdout
5. Agent parses output and continues workflow

## Tasks

### 1. `ai/install-deps.sh` — Auto-detect and install dependencies
- **File**: `etc/scripts/ai/install-deps.sh` (new)
- **What**: Detect package manager (npm/pnpm/bun/yarn/maven/gradle/pip/cargo/go) and run the install command. Detection logic already exists in `run-tests.sh` and `worktrees/lib/core.sh` — extract and reuse patterns.
- **Accepts**: Optional `--frozen` flag for CI-style lockfile-only installs
- **Dependencies**: None
- **Complexity**: Small
- **Parallel**: Yes

### 2. `ai/lint-check.sh` — Auto-detect and run linter
- **File**: `etc/scripts/ai/lint-check.sh` (new)
- **What**: Detect linter (eslint, biome, checkstyle via maven/gradle, ruff, golangci-lint, cargo clippy) and run it. Output exit code and summary of issues found.
- **Detection**: Check for config files (`eslint.config.*`, `.eslintrc.*`, `biome.json`, `pyproject.toml` with ruff, `pom.xml` with checkstyle plugin, `.golangci.yml`)
- **Accepts**: Optional `--fix` flag to auto-fix
- **Dependencies**: None
- **Complexity**: Medium
- **Parallel**: Yes

### 3. `ai/git-branch-info.sh` — Consolidated git branch context
- **File**: `etc/scripts/ai/git-branch-info.sh` (new)
- **What**: Output current branch, base branch (develop > main > master), ahead/behind counts, uncommitted file count, staged file count, diff stat summary. Replaces 3-5 separate `git` calls that most OpenCode commands make at startup.
- **Output**: Key-value pairs, one per line (e.g., `CURRENT_BRANCH=feature/foo`, `BASE_BRANCH=develop`, `AHEAD=3`, `BEHIND=0`, `UNCOMMITTED=2`)
- **Dependencies**: None
- **Complexity**: Small
- **Parallel**: Yes

### 4. `ai/detect-stack.sh` — Full tech stack detection
- **File**: `etc/scripts/ai/detect-stack.sh` (new)
- **What**: Extend `project-info.sh` to also detect: linter, test runner, CI system (GitHub Actions, GitLab CI), database (from docker-compose or config files), monorepo tool (turborepo, nx, lerna), CSS framework, bundler. Output as key-value pairs.
- **Dependencies**: None
- **Complexity**: Medium
- **Parallel**: Yes

### 5. `ai/pr-status.sh` — PR status summary
- **File**: `etc/scripts/ai/pr-status.sh` (new)
- **What**: List open PRs for current repo with: title, branch, check status (pass/fail/pending), review status (approved/changes-requested/pending), merge conflict status. Wraps `gh pr list` + `gh pr view`.
- **Accepts**: Optional `--mine` flag to filter to current user's PRs
- **Dependencies**: `gh` CLI
- **Complexity**: Small
- **Parallel**: Yes

### 6. `ai/scaffold-spec.sh` — Spec file template generator
- **File**: `etc/scripts/ai/scaffold-spec.sh` (new)
- **What**: Create a `plans/<name>.md` file with standard section headers (Overview, Architecture, Data flow, Tasks, API contracts, State changes, Edge cases, Testing approach, Open questions). Accepts optional `--todoist <url>` to add YAML frontmatter. Handles filename collision by appending numeric suffix.
- **Accepts**: `<prefix>` `<name>` and optional `--todoist <url>`
- **Dependencies**: None
- **Complexity**: Small
- **Parallel**: Yes

### 7. `ai/changelog.sh` — Generate changelog from git history
- **File**: `etc/scripts/ai/changelog.sh` (new)
- **What**: Generate a grouped changelog between two refs (default: last tag to HEAD). Groups commits by conventional commit type (feat, fix, chore, etc.). Outputs markdown.
- **Accepts**: Optional `<from-ref>` `<to-ref>`
- **Dependencies**: None
- **Complexity**: Small
- **Parallel**: Yes

### 8. `ai/security-scan.sh` — Combined security check
- **File**: `etc/scripts/ai/security-scan.sh` (new)
- **What**: Run dependency audit (reuse `check-deps.sh` logic) plus secret scanning (check for high-entropy strings, `.env` files in git, common secret patterns in tracked files). Not a replacement for trufflehog but a quick heuristic scan.
- **Dependencies**: None
- **Complexity**: Medium
- **Parallel**: Yes

### 9. `ai/validate-opencode.sh` — OpenCode config validator
- **File**: `etc/scripts/ai/validate-opencode.sh` (new)
- **What**: Validate all SKILL.md files have non-empty content, all command .md files have valid frontmatter (description field), all agents referenced in AGENTS.md exist in `agent/`, all skills referenced in AGENTS.md exist in `skills/`. Report broken references.
- **Target directory**: `src/opencode/`
- **Dependencies**: None
- **Complexity**: Medium
- **Parallel**: Yes

## API contracts

All scripts follow the same interface:
- Exit 0 on success, non-zero on failure
- Output to stdout (parseable by agents)
- Errors/warnings to stderr via `log_error`/`log_warning`
- Accept `--help` flag for usage info

## State changes

No database, config, or environment changes. Scripts are read-only operations (except `install-deps.sh` which modifies `node_modules`/equivalent, and `scaffold-spec.sh` which creates files).

## Edge cases

- **No package manager detected**: `install-deps.sh` and `lint-check.sh` should exit 1 with a clear message, not fail silently
- **Multiple linters present**: `lint-check.sh` should pick the primary one (prefer eslint over biome if both exist, or run both with a `--all` flag)
- **Monorepo root vs package**: Scripts should work from any directory, detecting if they're in a monorepo root or a sub-package
- **Missing tools**: `pr-status.sh` needs `gh`, `security-scan.sh` benefits from `trufflehog` — scripts should degrade gracefully with a warning if optional tools are missing
- **Git not initialized**: `git-branch-info.sh` should handle non-git directories

## Testing approach

- Manual testing: Run each script in representative project types (Node/TS, Java/Spring, Python, Go)
- Validate exit codes and output format
- Test edge cases: no package manager, no git, monorepo, missing tools

## Decisions

1. **detect-stack.sh replaces project-info.sh** — detect-stack.sh becomes the single source of truth. Remove project-info.sh after migration.
2. **Key-value output format** — All scripts output `KEY=VALUE` lines, matching existing conventions. No JSON/jq dependency.
3. **Integrate trufflehog/gitleaks if available** — security-scan.sh uses trufflehog/gitleaks when installed, falls back to heuristic grep patterns otherwise.
4. **Warn about deprecated references** — validate-opencode.sh flags any AGENTS.md or config references pointing to `_depreciated/` items.
