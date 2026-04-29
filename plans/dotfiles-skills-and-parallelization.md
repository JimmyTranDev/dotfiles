## Overview

New skills and improvements to parallelization patterns: a psql connection skill, utility shell scripts for AI agents, parallelization improvements (instant-write optimization, tiny batch delegation), and a local AI setup.

## Architecture

Skills live at `src/opencode/skills/<name>/SKILL.md`. Shell scripts live at `etc/scripts/`. Parallelization changes modify the existing `meta-parallelization` skill. The AGENTS.md parallelization section may also need updates.

## Data flow

- Skills are loaded on-demand via the Skill tool when a task matches
- Shell scripts are called via Bash tool by AI agents during task execution
- Parallelization patterns guide how agents fan out work

## Tasks

### 1. Create `tool-psql` skill
- **File**: `src/opencode/skills/tool-psql/SKILL.md` (new)
- **Changes**: Create skill documenting psql CLI usage: connection strings, common queries, schema inspection (`\dt`, `\d table`), data export, transaction handling, and Cloud SQL Proxy connection patterns (already in Brewfile). Include common workflows: check table structure, run migration manually, inspect data, compare schemas.
- **Complexity**: medium
- **Parallel**: yes

### 2. Add utility shell scripts for AI agents
- **Files**: Multiple new files in `etc/scripts/ai/` (new directory)
- **Changes**: Create shell scripts that AI agents can call for common tasks. Initial set:
  - `etc/scripts/ai/project-info.sh` — detect project type (Java/Node/Python), list key files, show build tool
  - `etc/scripts/ai/run-tests.sh` — detect test framework and run tests with coverage
  - `etc/scripts/ai/check-deps.sh` — check for outdated/vulnerable dependencies
  - All scripts follow existing conventions: `set -e`, source `common/logging.sh`, function-based structure
- **Dependencies**: Needs `etc/scripts/common/logging.sh` (already exists)
- **Complexity**: medium
- **Parallel**: yes

### 3. Parallelization: instant-write when single thread handles a file
- **File**: `src/opencode/skills/meta-parallelization/SKILL.md` (modify)
- **Changes**: Add pattern: when a parallel fan-out has only one agent handling a given file, that agent should write directly instead of collecting changes and consolidating in the parent. Only consolidate when multiple agents touch the same file. Add decision rule to the fan-out section.
- **Complexity**: small
- **Parallel**: yes

### 4. Parallelization: prefer tiny batches to more agents
- **File**: `src/opencode/skills/meta-parallelization/SKILL.md` (modify)
- **Changes**: Add guidance: when delegating N tasks, prefer launching more agents with fewer tasks each (e.g., 5 agents x 2 tasks) over fewer agents with many tasks (e.g., 2 agents x 5 tasks). Define sizing heuristic: ~2-3 tasks per agent for small tasks, ~1 task per agent for medium/large.
- **Dependencies**: Task 3 (same file, apply sequentially)
- **Complexity**: small
- **Parallel**: no (depends on task 3)

### 5. Add local AI setup
- **File**: `src/opencode/skills/tool-local-ai/SKILL.md` (new) or modify `src/opencode/opencode.json`
- **Changes**: Document how to set up local AI models (Ollama, LM Studio) for use with OpenCode. Cover: installation, model selection, configuration in `opencode.json`, when to use local vs cloud, performance expectations.
- **Complexity**: medium
- **Parallel**: yes

### 6. AI-generated scripts saved to dotfiles
- **File**: `src/opencode/AGENTS.md` (modify) or new skill
- **Changes**: Add convention: when an AI agent creates a useful utility script during a task, it should save it to `etc/scripts/ai/` in the dotfiles repo rather than leaving it in the project. This makes scripts reusable across projects.
- **Dependencies**: Task 2 (directory must exist first)
- **Complexity**: small
- **Parallel**: no (depends on task 2)

## API contracts

Shell script interface:
```bash
#!/usr/bin/env bash
set -e
source "$(dirname "$0")/../common/logging.sh"
# Each script outputs structured info to stdout
# Exit 0 on success, non-zero on failure
```

## State changes

- New directory: `etc/scripts/ai/`
- New skill directories: `src/opencode/skills/tool-psql/`, possibly `src/opencode/skills/tool-local-ai/`
- Modified: `meta-parallelization/SKILL.md`

## Edge cases

- Task 2: Scripts called outside dotfiles repo — should detect and use generic paths
- Task 5: No GPU available — document CPU-only options and performance impact
- Task 3: All files handled by multiple agents — instant-write never applies, consolidation is still correct

## Testing approach

- Task 2: Run each script in a sample Java and Node project, verify output
- Tasks 3-4: Apply patterns in a real parallel PR workflow and verify behavior
- Task 1, 5: Load skill in OpenCode and verify it provides useful guidance

## Open questions

- Task 2: Should scripts live in `etc/scripts/ai/` or `etc/scripts/common/`?
- Task 5: Ollama vs LM Studio vs both? Which models to recommend?
- Task 2: What's the initial set of scripts? Just the 3 listed or more?
- Task 6: Should this be a convention in AGENTS.md or a dedicated skill?
