---
todoist:
  - https://app.todoist.com/app/task/create-command-to-innovate-and-improve-the-local-opencode-config-6grvHF2WGW32FvwH
  - https://app.todoist.com/app/task/make-it-so-that-open-code-creates-and-updates-skills-from-what-it-learns-6gvCv96vqf4JGrMF
  - https://app.todoist.com/app/task/create-clarify-todoist-command-that-have-options-to-explain-or-downgrade-or-delete-6gvFw93RQx3R73pm
---

# Devtools: OpenCode Meta Commands & Self-Improvement

## TL;DR
- Covers 3 p1 tasks that extend OpenCode's own config: a new `/innovate-opencode` command, a new `/learn` command that creates/updates skills, and a new clarify-todoist command with explain/downgrade/delete options.
- Touches `src/opencode/command/`, `src/opencode/skills/`, and the `opencode-to-claude.sh` regeneration step.
- **#4 and #25 still begin with an audit** of existing pieces (`/opencode`, `strategy-innovate`, `meta-skill-learnings`, `meta-auto-improve`) — not to decide new-vs-enhance (both are new commands) but to define exactly how they compose those pieces and avoid duplication.
- Most critical: avoid duplicating existing skills/commands — the audit is the gating step.
- Estimated effort: ~1 day, dominated by the audit + careful authoring. The clarify-todoist command (#new) is the most self-contained; its workflow is already proven in this session.

## Overview
Three meta tasks that improve how OpenCode configures and improves itself: (1) a command to brainstorm and apply improvements to the local opencode config, (2) a mechanism for OpenCode to create/update skills from what it learns, and (3) a Todoist-clarify command offering per-task explain/downgrade/delete actions. All three risk overlapping existing config, so each begins with an audit.

## Architecture
- **Commands**: `src/opencode/command/*.md` (slash commands). Existing relevant: `opencode.md` (analyze project + suggest agents/commands/skills), `clarify.md`, `triage-todoist-section.md`, `triage.md`.
- **Skills**: `src/opencode/skills/<name>/SKILL.md`. Existing relevant: `strategy-innovate`, `meta-auto-improve` ("proactive improvement of skills/commands after every task"), `meta-skill-learnings` ("improve skills when discovering bugs/gotchas"), `meta-opencode-authoring`.
- **Generation**: `~/.claude/` is regenerated from `src/opencode/` via `etc/scripts/src/ai/opencode-to-claude.sh`. Any new command/skill must be re-synced.

## Data flow
1. User invokes `/command` → command markdown drives the agent, which may load skills and write to `plans/` or edit `src/opencode/`.
2. New/edited skills under `src/opencode/skills/` are auto-discovered by OpenCode; the converter mirrors them into `~/.claude/skills/`.

## Tasks
| # | File | Change | Complexity | Deps | Parallel? |
|---|------|--------|------------|------|-----------|
| 1 | (audit, write findings to this spec) | Audit `/opencode`, `strategy-innovate`, `meta-auto-improve`, `meta-skill-learnings` to map overlap and define how the new commands compose them (not whether to build — that is decided below) | Medium | None | Yes |
| 2 | `src/opencode/command/innovate-opencode.md` (new) | #4: new command that composes `/opencode` analysis + `strategy-innovate` to brainstorm & propose improvements to the **local dotfiles opencode config** (agents/commands/skills); surfaces a diff before applying | Medium | 1 | Sequential after 1 |
| 3 | `src/opencode/command/learn.md` (new) + skill wiring | #25: new `/learn` command that creates or updates skills from what was learned in a session — dedup against existing skills, write `skills/<name>/SKILL.md`, human review gate. Reuse `meta-skill-learnings`/`meta-opencode-authoring` patterns | Large | 1 | Sequential after 1 |
| 4 | `src/opencode/command/clarify-todoist.md` (new) | #new: a new command with per-task explain / downgrade-priority / delete options over a Todoist section/project URL. Reuse this session's `td` CLI + question-tool workflow | Medium | None | Yes |
| 5 | regenerate `~/.claude/` | Run `opencode-to-claude.sh` after command/skill changes | Small | 2,3,4 | Sequential |

## API contracts
- **#4 command**: writes proposals to `plans/` and (optionally) edits `src/opencode/` — must not silently mutate config without surfacing a diff.
- **#25 workflow**: define the trigger (after-task hook? explicit command?) and the write target (`skills/<name>/SKILL.md`) plus a dedup check against existing skills.
- **#new clarify-todoist command**: input = Todoist section/project URL `[+ priority token]`; per task offers `{explain, downgrade, delete, skip}`; applies via `td task update/delete/complete`.

## State changes
- New/edited markdown under `src/opencode/command/` and `src/opencode/skills/`.
- Regenerated `~/.claude/` (untracked).
- AGENTS.md command-taxonomy table may need a new row for the clarify-todoist command.

## Edge cases
- #4/#25 producing changes that duplicate an existing skill/command → audit (task 1) must prevent this.
- #25 self-writing a skill that conflicts with an existing name → require a name-collision check before writing.
- clarify-todoist on a section URL (`td view` rejects section URLs) → use the `triage-todoist.sh` / `td section list` workaround.
- Destructive actions (delete) → require confirmation (`td task delete --yes` only after explicit user choice).

## Open questions
### Architecture
- **#4: Decision — new `/innovate-opencode` command** that composes `/opencode` analysis + `strategy-innovate`, targeting the dotfiles opencode config itself (not arbitrary projects). The audit (task 1) defines exactly how it reuses those pieces.
- **#25: Decision — new `/learn` command** that creates or updates skills from session learnings (dedup + human review gate), reusing `meta-skill-learnings`/`meta-opencode-authoring`. `meta-auto-improve` remains the passive after-task trigger; `/learn` is the explicit on-demand path.
### Scope
- **#new clarify-todoist: Decision — new focused command** (`clarify-todoist.md`) with explain/downgrade/delete options, separate from the generic `clarify.md` and `triage-todoist-section.md`.
### Risks
- Self-updating skills (#25) could degrade skill quality if unsupervised — the `/learn` command must keep a human-in-the-loop review gate before writing/overwriting a skill.
