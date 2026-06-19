---
name: innovate-opencode
description: Brainstorm and propose improvements to the local OpenCode dotfiles config, surfacing a diff before applying
---

Usage: /innovate-opencode [focus area: agents | commands | skills | all]

Brainstorm high-value improvements to the **local dotfiles OpenCode config** (`src/opencode/` — agents, commands, skills, AGENTS.md) and propose them as a reviewable change. Never silently mutate config: every edit is surfaced for approval before it is applied.

$ARGUMENTS

## Composition (audit)

This command composes existing pieces — it does not duplicate them:

- **`/opencode`** provides the analysis framework (suggest skills/commands/agents across dimensions, filter duplicates, rank by impact). `/opencode` targets an *arbitrary project* to bootstrap its config; `/innovate-opencode` turns that same lens **inward** on the dotfiles opencode config itself, to improve what already exists.
- **strategy-innovate** (skill) supplies the ideation frameworks — SCAMPER, pain-point mining, the impact-effort matrix, and the idea presentation format — used to generate and rank ideas.
- vs **meta-auto-improve** (skill): that is the *passive, after-every-task* fixer for inaccuracies in the skills/commands you just used. `/innovate-opencode` is the *on-demand, proactive* path that brainstorms net-new agents/commands/skills and structural improvements.
- vs **/learn**: `/learn` writes skills from *session learnings*; `/innovate-opencode` brainstorms *net-new ideas* from a full-config analysis.

## Workflow

1. Determine scope from `$ARGUMENTS`:
   - `agents`, `commands`, or `skills` — focus on that layer
   - `all` or empty — analyze the full `src/opencode/` config

2. Load skills in parallel: **strategy-innovate**, **meta-opencode-authoring**, **code-follower**.

3. Inventory the current config (run in parallel):
   - List `src/opencode/agent/`, `src/opencode/command/`, and `src/opencode/skills/`
   - Read `src/opencode/AGENTS.md` for the existing taxonomy, conventions, and structure
   - Skim recent git history touching `src/opencode/` to understand the direction of recent changes

4. Analyze for improvement opportunities, reusing `/opencode`'s dimensions scoped to this config:
   - **Missing skills** — recurring domain knowledge not yet captured
   - **Missing/weak commands** — repetitive workflows that deserve a slash command
   - **Missing agents** — specialized roles not covered by existing agents
   - **Overlap/redundancy** — commands, skills, or agents that duplicate each other and should be consolidated
   - **Gaps & inconsistencies** — stale references, missing cross-links, taxonomy drift
   Apply **strategy-innovate** frameworks (SCAMPER, pain-point mining) and score each idea on the impact-effort matrix.

5. Filter proposals (the dedup gate):
   - Drop anything already covered by an existing agent/command/skill
   - Drop anything too generic to be worth a dedicated config artifact
   - Keep 5-10 high-value proposals

6. Write proposals to `plans/innovate-opencode-<focus>.md` using **strategy-innovate**'s Idea Presentation Format (name, category, description, effort, impact, entry point, patterns, next step), ranked by impact-effort. If the file already exists, append a numeric suffix.

7. Surface before applying:
   - Present the ranked proposals and use the question tool to let the user pick which (if any) to apply
   - For each chosen proposal, show the exact new file content or an edit diff **before writing it** — never silently mutate config

8. Apply only approved changes:
   - Create or edit files under `src/opencode/` following **meta-opencode-authoring** conventions and the existing naming taxonomy
   - After applying, remind the user that `~/.claude/` must be regenerated via `opencode-to-claude.sh`, and that the AGENTS.md taxonomy tables may need a new row

## Rules

- Default mode is propose-only — the `plans/` file is always written; config edits happen only after explicit per-proposal approval
- Never duplicate an existing skill/command/agent — consolidation is preferred over addition
- Match the existing naming taxonomy and frontmatter conventions for any new artifact
