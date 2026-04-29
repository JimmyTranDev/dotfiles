## Overview

New OpenCode slash commands for the dotfiles project: `/quiz` (spec-then-quiz learning), `/merge-specs` (combine spec files), `/fms` (generate FMS JSON), `/migration-check` (check DB migrations), and `/commit-summary` (date-ranged commit report). Each follows the existing command authoring conventions in `meta-opencode-authoring`.

## Architecture

All commands live at `src/opencode/command/<name>.md` with YAML frontmatter (`name`, `description`). They are auto-discovered by OpenCode. Commands use `$ARGUMENTS` for user input, the `question` tool for interactive choices, and delegate to subagents via the `Task` tool. New skills referenced by commands go in `src/opencode/skills/<name>/SKILL.md`.

## Data flow

Each command reads `$ARGUMENTS` → gathers context (codebase, git, files) → processes → writes output (spec files, markdown, JSON) or interacts via question tool.

## Tasks

### 1. `/quiz` command
- **File**: `src/opencode/command/quiz.md` (new)
- **Changes**: Create command that: (1) runs `/specify` or reads an existing spec, (2) walks through each task asking the user "what would you do here?" via the question tool, (3) scores answers against the spec, (4) optionally implements after quiz
- **Dependencies**: Depends on existing `/specify` command pattern
- **Complexity**: large
- **Parallel**: yes (independent of other tasks)

### 2. `/merge-specs` command
- **File**: `src/opencode/command/merge-specs.md` (new)
- **Changes**: Create command that lists spec files in `spec/`, lets user multi-select via question tool, reads all selected, merges into a single consolidated spec, writes to `spec/<merged-name>.md`, optionally deletes originals
- **Dependencies**: None
- **Complexity**: medium
- **Parallel**: yes

### 3. `/fms` command
- **File**: `src/opencode/command/fms.md` (new)
- **Changes**: Create command that takes keys/descriptions as `$ARGUMENTS`, generates a JSON array of objects with `key`, `no`, `en` fields. Output to clipboard or file. Uses AI to translate if only one language provided.
- **Dependencies**: None
- **Complexity**: small
- **Parallel**: yes

### 4. `/migration-check` command
- **File**: `src/opencode/command/migration-check.md` (new)
- **Changes**: Create command that checks for pending Flyway/Liquibase migrations by examining `src/main/resources/db/migration/` or equivalent, compares against current DB state or branch diff, reports which migrations are new/pending
- **Dependencies**: May reference `tool-spring-boot` skill for Java project detection
- **Complexity**: medium
- **Parallel**: yes

### 5. `/commit-summary` command
- **File**: `src/opencode/command/commit-summary.md` (new)
- **Changes**: Create command that runs `git log` with configurable date range (user selects via question tool or `$ARGUMENTS`), groups commits by type/scope, generates a human-readable summary, dumps to markdown file
- **Dependencies**: None
- **Complexity**: small
- **Parallel**: yes

## API contracts

Each command follows the standard frontmatter:
```yaml
---
name: <command-name>
description: <1-line description>
---
```

## State changes

- `/merge-specs` creates files in `spec/` and optionally deletes originals
- `/commit-summary` creates markdown files (e.g., `commit-summary-2026-04.md`)
- `/fms` outputs JSON to stdout or clipboard

## Edge cases

- `/quiz`: No spec files exist — should offer to generate one first
- `/merge-specs`: Only one spec file — warn and skip
- `/migration-check`: Not a Java project — report and exit
- `/fms`: Empty arguments — prompt for keys interactively
- `/commit-summary`: No commits in date range — report empty

## Testing approach

Manual testing only — these are markdown instruction files, not executable code. Verify by running each command in OpenCode and checking output.

## Decisions (resolved)

- `/quiz`: Numeric scoring — correct/incorrect per step + total score (e.g., 7/10)
- `/quiz`: Supports both `spec/` and `plans/` files
- `/fms`: Key format is dot-notation (e.g., `page.login.title`)
- `/migration-check`: Flyway only
- `/commit-summary`: Include PR links via `gh` CLI where available
