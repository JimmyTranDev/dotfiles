---
name: learn
description: Create or update skills from session learnings with a dedup check and human review gate
---

Usage: /learn [topic or "all"]

Turn reusable insights from the current session into skills — creating a new `skills/<name>/SKILL.md` or updating an existing skill — behind a name-collision check and a human review gate. Nothing is written until you approve it.

$ARGUMENTS

## Composition (audit)

This command is the explicit, on-demand path for skill authoring. It composes existing pieces rather than restating them:

- **meta-skill-learnings** (skill) supplies the decision logic — improve an existing skill vs create a new one, what qualifies, and the per-format additions. This command *loads and applies* it; it does not restate the rules.
- **meta-opencode-authoring** (skill) supplies the SKILL.md structure and frontmatter rules for any new skill.
- vs **meta-auto-improve** (skill): that remains the *passive after-every-task* trigger that corrects existing skill/command content. `/learn` is the *explicit on-demand* trigger focused on skill creation/update from a whole session.
- vs **/learn-opencode** (command): that updates the *whole* config (skills, agents, AND AGENTS.md). `/learn` is scoped narrowly to **skills only** (`skills/<name>/SKILL.md`), with a strict name-collision/dedup gate and confirmation before any overwrite. Use `/learn` for skill-only capture; reach for `/learn-opencode` when the learnings also touch agents or AGENTS.md rules.

## Workflow

1. Load skills in parallel: **meta-skill-learnings**, **meta-opencode-authoring**.

2. Scan the current session for reusable, generalizable insights: bug patterns, gotchas, anti-patterns, missing edge cases, and workflows worth standardizing. If `$ARGUMENTS` names a topic, focus on it; if `all` or empty, scan everything.

3. Filter using **meta-skill-learnings**'s "What Does NOT Qualify" — drop one-off bugs, project-specific business logic, and unbacked style opinions.

4. Route each surviving insight via the **meta-skill-learnings** decision table:
   - Fits an existing skill's domain → update that skill
   - Spans multiple skills → update the most relevant, cross-reference the others
   - New domain not covered by any skill → candidate for a new skill

5. Dedup / name-collision check (required before any new skill):
   - List existing skills under `src/opencode/skills/`
   - If a new skill's domain is already covered by an existing skill, propose updating that skill instead of creating a duplicate
   - If a proposed new skill name collides with an existing directory, either target the existing skill or pick a non-colliding name — never overwrite by accident

6. Human review gate — present every proposed change before writing:
   - For each: the target (new `skills/<name>/SKILL.md` vs an existing skill), whether it is a create or an overwrite, and the exact content to add or the full new SKILL.md
   - Use the question tool per item: **Apply**, **Edit**, or **Skip**
   - Overwriting an existing skill requires explicit confirmation

7. Apply only approved changes:
   - New skill: write `src/opencode/skills/<name>/SKILL.md` with valid frontmatter (`name` matching the directory, a specific `description`) per **meta-opencode-authoring**
   - Existing skill: add the insight in the skill's existing format (table row, code block, or bullet) per **meta-skill-learnings**
   - After applying, remind the user that `~/.claude/` must be regenerated via `opencode-to-claude.sh`

## Rules

- Never write or overwrite a skill without explicit approval — the review gate is mandatory
- Never duplicate knowledge already present in a skill — prefer updating over adding
- Keep additions concise and actionable (pattern, what goes wrong, fix) — not paragraphs
- One skill per domain — do not create a near-duplicate of an existing skill
