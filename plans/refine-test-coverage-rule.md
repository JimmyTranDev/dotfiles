# Refine 100% Test Coverage Rule in AGENTS.md

## Overview

The current "100% test coverage" rule in `src/opencode/AGENTS.md` (line 19) is a blanket statement that applies to all code changes everywhere. This spec refines it to be backend-specific: 100% unit test coverage is required for new/modified backend code (Java, TypeScript services, etc.), while config-only projects, markdown, and shell scripts are exempt.

## Architecture

Single file change: `src/opencode/AGENTS.md`, Universal Rules section (line 19).

The AGENTS.md is loaded by `opencode.json` via the `instructions` array and acts as the global LLM behavior ruleset across all projects where OpenCode runs.

## Data flow

N/A — this is a configuration change, not a code flow.

## Tasks

| # | File | Change | Complexity | Parallel? |
|---|------|--------|------------|-----------|
| 1 | `src/opencode/AGENTS.md` | Rewrite the "100% test coverage" bullet in Universal Rules to scope it to backend code (Java, TypeScript/Node services, Python APIs, etc.) and clarify what counts as backend vs config-only | small | — |

### Task 1 detail

Replace the current rule (line 19):

```
- **100% test coverage** — when writing or modifying code, always ensure 100% unit test coverage for all affected code. This includes new code, modified functions, and any code paths touched by the changes. Load the **test** skill, write or update tests, and run them to verify full coverage before considering the task complete.
```

With a refined version that:
- Specifies this applies to **backend/service code** (Java, TypeScript/Node APIs, Python, etc.)
- Clarifies "new code" means new functions, classes, and logic paths — not config files
- Exempts markdown, JSON config, shell scripts, and purely declarative files
- Keeps the instruction to load the **test** skill and run tests
- Keeps the 100% target for new code, but acknowledges modifying existing code should maintain or improve existing coverage (not necessarily 100% retroactively)

## API contracts

N/A

## State changes

N/A — no new config entries, env vars, or stored state.

## Edge cases

- Projects with no test infrastructure: the rule should instruct the agent to set up a test runner if one doesn't exist (already implied by "load the test skill")
- Mixed projects (backend + config): rule should apply only to the backend portions
- Shell scripts: these are harder to unit test — rule should note integration/smoke tests are acceptable for shell scripts

## Testing approach

Manual review — read the updated AGENTS.md and verify the rule is clear and scoped correctly. No automated tests for a markdown config change.

## Open questions

### Requirements
- **Coverage target for modified legacy code**: Should the rule require backfilling tests for untested legacy code that gets modified, or only cover the new/changed lines? (Current recommendation: cover new/changed code, improve but don't mandate 100% for legacy)

### Scope
- **Shell scripts**: Should the `etc/scripts/` shell scripts in this dotfiles repo be subject to any test coverage requirement, or fully exempt? (Current recommendation: exempt, since they're operational scripts not service code)
