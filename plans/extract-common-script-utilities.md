# Extract Common Script Utilities

## TL;DR

- 6 functions are duplicated across 13+ script files in `etc/scripts/`
- Create 2 new common files: `common/detect.sh` (stack detection) and `common/git.sh` (git helpers)
- Add `require_tool()` to existing `common/utility.sh`
- Remove duplicates from `ai/`, `worktrees/` scripts and replace with `source` calls
- Estimated effort: medium (mostly mechanical find-and-replace, but needs testing across bash and zsh callers)

## Overview

Multiple scripts in `etc/scripts/ai/` and `etc/scripts/worktrees/` re-implement the same functions: package manager detection, linter detection, test runner detection, base branch detection, slugify, and tool availability checks. This spec extracts those into `common/` modules so each function has a single source of truth. Only shell-agnostic (POSIX-compatible) functions are extracted; zsh-specific color output (`print -P`) stays in worktrees.

## Architecture

```
etc/scripts/common/
├── logging.sh          # existing (bash color output)
├── utility.sh          # existing + add require_tool()
├── git_diff_commits.sh # existing (standalone)
├── detect.sh           # NEW: detect_node_package_manager, detect_package_manager, detect_linter, detect_test_runner
└── git.sh              # NEW: find_base_branch, require_git_repo
```

All `common/*.sh` files remain bash (`#!/bin/bash`). Worktrees (zsh) can source them because the extracted functions use only POSIX-compatible constructs (`echo`, `[[ ]]`, `command -v`, `sed`, `tr`).

## Data flow

Not applicable (utility libraries, no data pipeline).

## Tasks

### Task 1: Create `common/detect.sh`
- **File**: `etc/scripts/common/detect.sh`
- **Action**: New file
- **Contents**:
  - `detect_node_package_manager()` -- check for pnpm-lock.yaml / yarn.lock / bun.lockb / package-lock.json, return package manager name. This is the "node-only" version used by most scripts.
  - `detect_package_manager()` -- full version from `ai/detect-stack.sh` covering all languages (node + mvn + gradle + poetry + pip + go + cargo)
  - `detect_linter()` -- merged from `ai/detect-stack.sh` and `ai/lint-check.sh` (superset of both)
  - `detect_test_runner()` -- from `ai/detect-stack.sh` / `ai/run-tests.sh`
- **Complexity**: small
- **Dependencies**: none
- **Parallel**: yes

### Task 2: Create `common/git.sh`
- **File**: `etc/scripts/common/git.sh`
- **Action**: New file
- **Contents**:
  - `find_base_branch()` -- check for develop/main/master via `git show-ref --verify` or `git rev-parse --verify`, return first match. Merge logic from `ai/git-branch-info.sh:find_base_branch()` and `worktrees/lib/core.sh:find_main_branch()`.
  - `require_git_repo()` -- run `git rev-parse --is-inside-work-tree` and exit/return 1 with error if not in a git repo
- **Complexity**: small
- **Dependencies**: none
- **Parallel**: yes (with Task 1)

### Task 3: Add `require_tool()` to `common/utility.sh`
- **File**: `etc/scripts/common/utility.sh`
- **Action**: Add function
- **Contents**:
  - `require_tool()` -- accepts one or more tool names, checks `command -v` for each, prints error and returns 1 on first missing tool
  - Source `logging.sh` if not already sourced (for `log_error`)
- **Complexity**: small
- **Dependencies**: none
- **Parallel**: yes (with Tasks 1-2)

### Task 4: Update `ai/detect-stack.sh`
- **File**: `etc/scripts/ai/detect-stack.sh`
- **Action**: Remove `detect_package_manager`, `detect_linter`, `detect_test_runner` function definitions. Add `source "$SCRIPT_DIR/../common/detect.sh"`. Call the common versions.
- **Complexity**: small
- **Dependencies**: Task 1
- **Parallel**: yes (with other Task 4-10 updates, after Task 1)

### Task 5: Update `ai/install-deps.sh`
- **File**: `etc/scripts/ai/install-deps.sh`
- **Action**: Remove local `detect_package_manager`. Source `common/detect.sh`. Replace calls with `detect_node_package_manager`.
- **Complexity**: small
- **Dependencies**: Task 1

### Task 6: Update `ai/lint-check.sh`
- **File**: `etc/scripts/ai/lint-check.sh`
- **Action**: Remove local `detect_package_manager` and `detect_linter`. Source `common/detect.sh`. Use `detect_node_package_manager` and `detect_linter`.
- **Complexity**: small
- **Dependencies**: Task 1

### Task 7: Update `ai/run-tests.sh`
- **File**: `etc/scripts/ai/run-tests.sh`
- **Action**: Remove local `detect_package_manager` and `detect_test_framework`. Source `common/detect.sh`. Use `detect_node_package_manager` and `detect_test_runner`.
- **Complexity**: small
- **Dependencies**: Task 1

### Task 8: Update `ai/git-branch-info.sh`
- **File**: `etc/scripts/ai/git-branch-info.sh`
- **Action**: Remove local `find_base_branch`. Source `common/git.sh`.
- **Complexity**: small
- **Dependencies**: Task 2

### Task 9: Update `worktrees/lib/core.sh`
- **File**: `etc/scripts/worktrees/lib/core.sh`
- **Action**:
  - Remove `slugify()` (already in `common/utility.sh`)
  - Remove `detect_package_manager()` -- source `common/detect.sh`, use `detect_node_package_manager`
  - Remove `find_main_branch()` -- source `common/git.sh`, use `find_base_branch`
  - Add source lines: `source "$SCRIPT_DIR/../../common/utility.sh"`, `source "$SCRIPT_DIR/../../common/detect.sh"`, `source "$SCRIPT_DIR/../../common/git.sh"`
  - Keep `print_color`, `select_fzf`, `check_tool`, `resolve_unique_dir`, `get_folder_name_from_branch`, `setup_project`, `select_project`, `install_dependencies`, `get_repository` (these are worktree-specific or use zsh features)
- **Complexity**: medium (need to verify all callers of renamed functions)
- **Dependencies**: Tasks 1, 2

### Task 10: Update `worktrees/commands/delete.sh`
- **File**: `etc/scripts/worktrees/commands/delete.sh`
- **Action**: Remove `get_worktree_project_name_zsh()`. Use `get_worktree_project_name` from `common/utility.sh` (sourced via core.sh in Task 9).
- **Complexity**: small
- **Dependencies**: Task 9

### Task 11: Update `ai/check-deps.sh` and `ai/security-scan.sh`
- **Files**: `etc/scripts/ai/check-deps.sh`, `etc/scripts/ai/security-scan.sh`
- **Action**: Replace inline package manager detection with `source common/detect.sh` + `detect_node_package_manager`.
- **Complexity**: small
- **Dependencies**: Task 1

### Task 12: Update `ai/weekly-summary.sh`
- **File**: `etc/scripts/ai/weekly-summary.sh`
- **Action**: Remove local `find_git_repos()`. Source `common/utility.sh`. Adapt call sites to use `find_git_repos` from utility.sh (note: the common version returns relative paths -- may need minor adjustment).
- **Complexity**: small
- **Dependencies**: Task 3

## API contracts

### `common/detect.sh` function signatures

```bash
detect_node_package_manager()
# No args. Checks CWD for lockfiles.
# Prints: "pnpm" | "yarn" | "bun" | "npm" | "" (empty if no lockfile)
# Returns: 0

detect_package_manager()
# No args. Checks CWD for lockfiles (all languages).
# Prints: "pnpm" | "yarn" | "bun" | "npm" | "maven" | "gradle" | "poetry" | "pip" | "go" | "cargo" | ""
# Returns: 0

detect_linter()
# No args. Checks CWD for linter config files.
# Prints: "biome" | "eslint" | "ruff" | "clippy" | "checkstyle-maven" | "checkstyle-gradle" | ""
# Returns: 0

detect_test_runner()
# No args. Checks CWD for test config/framework indicators.
# Prints: "vitest" | "jest" | "mocha" | "pytest" | "go" | "cargo" | "maven" | "gradle" | ""
# Returns: 0
```

### `common/git.sh` function signatures

```bash
find_base_branch()
# Arg 1 (optional): repo directory (default: CWD)
# Prints: "develop" | "main" | "master"
# Returns: 0 on success, 1 if no main branch found

require_git_repo()
# No args. Checks CWD.
# Prints error to stderr if not a git repo
# Returns: 0 if git repo, 1 if not
```

### `common/utility.sh` additions

```bash
require_tool()
# Args: one or more tool names
# Prints error to stderr for each missing tool
# Returns: 0 if all present, 1 if any missing
```

## State changes

No new config, env vars, or stored state. Only new files in `common/`.

## Edge cases

- **`find_base_branch` vs `find_main_branch` priority**: `worktrees/lib/core.sh` checks develop first, then main, then master. `ai/git-branch-info.sh` does the same. Keep this order in the unified version.
- **`detect_node_package_manager` vs `detect_package_manager`**: Scripts that only handle Node projects should call `detect_node_package_manager` (faster, no false positives from pom.xml in a monorepo). Scripts doing full stack detection call `detect_package_manager`.
- **SCRIPT_DIR resolution**: Each consuming script already sets its own `SCRIPT_DIR`. The `source` paths must be relative to each script's location. For `ai/*.sh` it's `"$SCRIPT_DIR/../common/detect.sh"`. For `worktrees/lib/core.sh` it's `"$SCRIPT_DIR/../../common/detect.sh"`.
- **Double-sourcing**: If multiple scripts source `common/detect.sh`, guard with `[[ -n "${_COMMON_DETECT_LOADED:-}" ]] && return 0` at the top to avoid re-execution.

## Testing approach

- Manual: run each updated ai/ script with `--help` to verify it still loads
- Manual: run `wD` (worktree delete), `wn` (worktree create), `wu` (worktree update) to verify worktree scripts still work
- Manual: run `detect-stack.sh` in a Node project and a Java project to verify detection still works
- Verify `find_base_branch` returns correct branch in repos with develop, repos with only main, and repos with only master

## Open questions

All resolved.

### Decisions
- **Q1**: `detect_node_package_manager` returns empty string when no lockfile found. Callers handle the empty case.
- **Q2**: `find_base_branch` priority is hardcoded: develop > main > master.
- **Q3**: `check_tool` (zsh, worktrees) stays separate from `require_tool` (bash, common/utility.sh).
