## Overview

New OpenCode subagents: a **critic** agent (devil's-advocate reviewer), a **fullstacker** agent (full-stack implementer), and improvements to the existing **reviewer** agent (self-validation + backend focus). Also covers auditing existing agents for gaps.

## Architecture

Agents live at `src/opencode/agent/<name>.md` with YAML frontmatter (`name`, `description`, `mode: subagent`). They are launched via the `Task` tool from commands or the main agent. Each agent loads relevant skills and follows a structured output format.

## Data flow

Agents receive a prompt describing the task → load skills → analyze code/diff → produce structured findings or implementation changes → return results to the calling agent.

## Tasks

### 1. Critic agent
- **File**: `src/opencode/agent/critic.md` (new)
- **Changes**: Create a devil's-advocate reviewer that is harsher than the standard reviewer. Loads `strategy-criticize`, `code-logic-checker`, `code-soundness` skills. Focuses on: assumptions that could be wrong, failure modes, things that look correct but aren't, over-engineering, missing error handling. Output format: prioritized list of concerns with severity and concrete counter-arguments.
- **Complexity**: medium
- **Parallel**: yes

### 2. Fullstacker agent
- **File**: `src/opencode/agent/fullstacker.md` (new)
- **Changes**: Create a full-stack implementer that plans and implements features spanning both backend (Java Spring) and frontend (React/TypeScript). Loads `tool-spring-boot`, `ts-total-typescript`, `code-conventions`, `code-follower` skills. Workflow: (1) analyze both layers, (2) define API contract, (3) implement backend, (4) implement frontend, (5) verify integration.
- **Complexity**: medium
- **Parallel**: yes

### 3. Reviewer agent — add self-validation
- **File**: `src/opencode/agent/reviewer.md` (modify)
- **Changes**: Add a self-validation step before outputting findings. For each finding, the reviewer should ask: "Is this actually a real issue? Could it be intentional? Does the codebase convention support this pattern?" Filter out false positives. Add a confidence level (high/medium/low) to each finding.
- **Complexity**: small
- **Parallel**: yes

### 4. Reviewer agent — backend focus research
- **File**: `src/opencode/agent/reviewer.md` (modify) or new skill `src/opencode/skills/review-backend/SKILL.md`
- **Changes**: Research and document what matters most for backend Java review: SQL injection, N+1 queries, transaction boundaries, thread safety, connection pool exhaustion, missing validation, incorrect HTTP status codes, missing error handling in async flows. Either add to reviewer.md or create a loadable skill.
- **Complexity**: medium
- **Parallel**: yes (after task 3 is done for reviewer.md, or parallel if separate skill)

### 5. Audit existing agents for gaps
- **File**: Multiple agent files (review only, no changes unless gaps found)
- **Changes**: Review all 9 existing agents against the meta-opencode-authoring quality checklist. Check: differentiation sections, skill loading, output format, edge case handling. Report gaps.
- **Complexity**: small
- **Parallel**: yes (independent research task)

## API contracts

Agent frontmatter pattern:
```yaml
---
name: <agent-name>
description: <1-line description shown in agent picker>
mode: subagent
---
```

Critic output format:
```
## CONCERN: <title>
- Severity: critical | high | medium | low
- What looks wrong: <description>
- Why it matters: <impact>
- Counter-argument: <why current approach might be intentional>
- Suggestion: <what to do instead>
```

## State changes

None — agents are instruction files only.

## Edge cases

- Critic agent called on trivial changes — should recognize when there's nothing to criticize and say so
- Fullstacker on backend-only or frontend-only projects — should detect and adapt
- Self-validation filtering out too many findings — keep a "suppressed findings" section so nothing is silently lost

## Testing approach

Manual testing: run each agent on a real diff/codebase and verify output quality.

## Decisions (resolved)

- Backend review: separate skill at `skills/review-backend/SKILL.md` (more reusable)
- Critic: on-demand only, not auto-included in review cycle
- Fullstacker: web only (Java Spring + React/TypeScript)
- Agent audit: report findings only, don't auto-fix
