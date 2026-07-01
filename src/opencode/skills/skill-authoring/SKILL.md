---
name: skill-authoring
description: Authors new agent skills as SKILL.md files. Use when creating a new skill, generating a skill, writing or scaffolding a SKILL.md, designing a reusable agent workflow, or adding a skill to src/opencode/skills/. Use when the user says "create a skill", "make a new skill", "author a skill", or "turn this workflow into a skill".
---

# Skill Authoring

## Overview

A skill is a reusable workflow an agent loads on demand to perform a specific task the same way every time. This skill encodes how to author a new skill for this repo so it is correctly structured, auto-discovered, and registered alongside the existing skills in `src/opencode/skills/`.

## When to Use

- The user asks to create, generate, scaffold, or author a new skill.
- A repeatable workflow has emerged that should be captured as a skill.
- You are converting a prompt, runbook, or set of conventions into a `SKILL.md`.

**Do NOT use when:**

- Editing opencode config (`opencode.json`, agents, plugins, MCP) — use `customize-opencode`.
- The task is a one-off; skills are for repeatable workflows, not single actions.
- A close-enough skill already exists — extend it instead of duplicating.

## Where Skills Live

In this repo, skills are the source of truth under:

```
src/opencode/skills/<skill-name>/SKILL.md
```

`src/opencode/` is symlinked to `~/.config/opencode/`. Author skills here.

```
src/opencode/skills/
  <skill-name>/
    SKILL.md            # Required: the skill definition
    scripts/            # Optional: only when the skill ships runnable helpers
    <supporting-file>.md # Optional: reference material loaded on demand
```

`SKILL.md` is the only required file. Do NOT create an empty `scripts/` directory to mirror other skills — empty directories add noise. Deprecated skills move to a `_depreciated/` subdirectory and are excluded from auto-discovery.

## The Workflow

### 1. Confirm a skill is the right tool

A skill must be **specific** (actionable steps, not vague advice), **verifiable** (clear exit criteria), **repeatable** (a real recurring workflow), and **minimal** (only what guides the agent). If any of these fail, stop and reconsider.

### 2. Check for overlap

Read `src/opencode/skills/using-agent-skills/SKILL.md` and scan existing skill names. If an existing skill covers ≥70% of the intent, extend it rather than create a near-duplicate. Skills should reference each other by name, not duplicate content.

### 3. Name it

- Lowercase, hyphen-separated, ≤64 chars (e.g. `skill-authoring`).
- The directory name MUST match the `name` field in frontmatter.
- Name by the task/workflow, not the tool (e.g. `frontend-ui-engineering`, not `react`).

### 4. Write the frontmatter (this is the contract)

```yaml
---
name: skill-name-with-hyphens
description: <What it does in third person>. Use when <specific trigger conditions>.
---
```

- `description` is effectively required — skills without one are filtered out and never surfaced to the model.
- Cover BOTH *what* the skill does AND *when* to trigger it. Write in third person ("Authors...", "Use when...").
- Front-load concrete trigger keywords, filenames, and the literal phrases a user is likely to say. Agents match on this text.
- Do NOT summarize the workflow steps in the description — if the description contains the process, the agent may follow the summary instead of reading the full skill.
- Use "Use ONLY when..." to gate a skill that should stay quiet on adjacent topics.
- Max 1024 chars.

### 5. Write the body

Follow the recommended section flow (equivalent headings like `How It Works` / `Core Process` / `Workflow` are fine):

```markdown
# Skill Title

## Overview
One or two sentences: what this skill does and why it matters.

## When to Use
- Positive triggers (symptoms, task types)
- "Do NOT use when..." exclusions

## The Workflow
Numbered steps or phases. Specific and actionable.
Use ASCII flowcharts where decision points exist; code/templates where they help.

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| Excuse to skip a step | Factual counter-argument |

## Red Flags
- Observable signs the skill is being violated

## Verification
- [ ] Checklist of exit criteria, each provable with evidence
```

### 6. Decide on supporting files

Add a supporting `.md` only when reference material exceeds ~100 lines, keeping the main `SKILL.md` focused (progressive disclosure). Keep patterns under ~50 lines inline. Add `scripts/` only when the skill ships real runnable helpers.

### 7. Register the skill in the discovery surfaces

Auto-discovery picks up the new `SKILL.md` from frontmatter, but this repo also maintains human/agent-facing maps that must be updated for the skill to be routed:

- `src/opencode/CLAUDE.md` — add a row to the relevant **Intent → Skill Mapping** table.
- `~/.config/opencode/CLAUDE.md` (global) — add to its mapping if the skill is global in nature.
- `src/opencode/skills/using-agent-skills/SKILL.md` — add to the discovery tree and the Quick Reference table.

### 8. Verify and propagate

Run the verification checklist below, then remind the user to **quit and restart opencode** — skills are loaded at startup and not hot-reloaded.

## Writing Principles

1. **Process over knowledge.** Steps the agent follows, not facts it reads.
2. **Specific over general.** "Run `npm test` and confirm all pass" beats "verify tests work".
3. **Evidence over assumption.** Every verification checkbox requires proof.
4. **Anti-rationalization.** Every skip-worthy step gets a counter-argument in the table.
5. **Token-conscious.** If removing a section wouldn't change agent behavior, remove it.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll write the body first and add frontmatter later." | Without a valid `description`, the skill is filtered out and never surfaced. Frontmatter is the contract — write it first. |
| "I'll summarize the steps in the description so it's discoverable." | Agents may follow the summary instead of reading the skill. Describe *what* and *when*, never the *how*. |
| "More sections make it more thorough." | Token-bloat degrades agent attention. Each section must justify its inclusion. |
| "I'll add a scripts/ folder like the other skills." | Empty directories add noise. Add `scripts/` only when shipping real helpers. |
| "Auto-discovery will pick it up, so I don't need to register it." | This repo's CLAUDE.md and `using-agent-skills` maps drive routing. Skipping them leaves the skill effectively invisible to the intent mapping. |
| "This workflow is close to an existing skill but mine is slightly different." | Near-duplicates fragment discovery. Extend the existing skill unless the intent is genuinely distinct. |
| "It's a one-off, but a skill makes it reusable." | Skills are for recurring workflows. A one-off belongs in a command or direct action, not a skill. |

## Red Flags

- `description` describes only *what* but not *when* (or vice versa).
- `name` and directory name don't match.
- The description spells out the step-by-step process.
- No `## Verification` section, or checkboxes that can't be proven with evidence.
- No `## Common Rationalizations` table for a process with skippable steps.
- An empty `scripts/` directory.
- The new skill overlaps heavily with an existing one.
- New skill not added to CLAUDE.md / `using-agent-skills` maps.
- A `README.md` or extra docs created without the user asking (repo rule: never create docs unless explicitly asked).

## Verification

After authoring the skill, confirm:

- [ ] File exists at `src/opencode/skills/<name>/SKILL.md` and the directory name matches `name`.
- [ ] Frontmatter has `name` (lowercase-hyphen, ≤64 chars) and a `description` covering both *what* and *when*, with front-loaded trigger keywords, ≤1024 chars.
- [ ] The description does not embed the step-by-step process.
- [ ] Body has Overview, When to Use, a Workflow, Common Rationalizations, Red Flags, and Verification (or clear equivalents).
- [ ] No empty `scripts/` directory; supporting files added only when justified.
- [ ] Registered in `src/opencode/CLAUDE.md` and `using-agent-skills/SKILL.md` (and global CLAUDE.md if applicable).
- [ ] User reminded to restart opencode so the skill loads.
