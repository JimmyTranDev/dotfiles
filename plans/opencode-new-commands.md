---
todoist: https://app.todoist.com/app/section/dotfiles-6f29Fcgcv4993gQG
---

# New OpenCode Commands

## Overview

Create new slash commands that expand OpenCode's capabilities: a senior mentor command, financial advisor command, architecture pros/con command, parallel check command, sync backend types command, learnings-from-chat command, testing instructions generation, and FMS.json root generation. These fill coverage gaps in the current command set.

## Architecture

All commands live in `src/opencode/command/<name>.md` with standard frontmatter (`name`, `description`, optional `model`). They follow existing conventions: markdown instructions with `$ARGUMENTS` placeholder, skill loading, and agent delegation patterns.

## Data flow

Each command is a standalone markdown file. No data dependencies between them. The commands instruct the LLM how to behave when invoked via `/command-name`.

## Tasks

| # | File | Change | Complexity | Parallel? |
|---|------|--------|------------|-----------|
| 1 | `src/opencode/command/mentor.md` | New file — senior mentor command that provides experienced engineering guidance, code review from a senior perspective, architecture advice, and career mentoring | medium | yes |
| 2 | `src/opencode/command/financial-advisor.md` | New file — financial advisor command for personal finance questions, budgeting, investment basics | medium | yes |
| 3 | `src/opencode/command/architecture-decision.md` | New file — architecture pros/con command that evaluates technical options with tradeoff analysis, writes ADR to `architecture/` folder at project root | medium | yes |
| 4 | `src/opencode/command/check.md` | New file — runs lint, test, build, typecheck in parallel and reports combined results | medium | yes |
| ~~5~~ | ~~`src/opencode/command/sync-types.md`~~ | ~~SKIPPED — downgraded to p3~~ | — | — |
| 6 | `src/opencode/command/learn.md` | New file — extracts learnings from current chat and updates relevant OpenCode config (skills, agents, AGENTS.md) | medium | yes |
| 7 | `src/opencode/command/test-instructions.md` | New file — generates testing instructions for QA from the current diff or spec, covering manual test steps and expected behaviors | medium | yes |
| 8 | `src/opencode/command/fms.md` | Modify existing — make it generate a `FMS.json` file at project root instead of (or in addition to) current behavior | small | yes |
| 9 | `src/opencode/command/dry-run.md` | New file — validates implementation plan without making changes, shows what would be created/modified | medium | yes |
| 10 | `src/opencode/command/combined-pr.md` | New file — creates a combined PR that merges multiple feature branches for test/deploy testing | large | yes |

## API contracts

Each command follows the standard frontmatter format:
```yaml
---
name: <command-name>
description: <one-line description>
model: <optional model override>
---
```

## State changes

- New files in `src/opencode/command/`
- `architecture-decision.md` creates `architecture/` directory in target projects
- `fms.md` modification changes output location to project root `FMS.json`
- `sync-types.md` creates/updates TypeScript type files in frontend projects

## Edge cases

- `check.md`: Must handle projects that don't have all four checks (lint/test/build/typecheck) — skip missing ones gracefully
- `sync-types.md`: Must handle when backend project is not accessible or types have changed incompatibly
- `combined-pr.md`: Must handle merge conflicts between feature branches
- `learn.md`: Must avoid duplicating existing knowledge in skills/agents

## Testing approach

- Manual testing: invoke each command and verify output matches expectations
- Verify frontmatter is valid YAML
- Verify commands load correct skills and follow conventions from `meta-opencode-authoring`

## Open questions

### Decisions
- Q1: Decision: Software engineering only — technical mentoring, architecture, code quality, career growth in tech
- Q2: Decision: No disclaimer needed
- Q3: Decision: Auto-detect from package.json/config — scan for available scripts and run what exists
- Q4: Decision: `architecture/` folder at project root
- Q5: Decision: Downgraded to p3 priority — skip for now
- Q6: Decision: Worktree branches only
