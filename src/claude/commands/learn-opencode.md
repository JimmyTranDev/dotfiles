---
description: Extract learnings from the current chat and update OpenCode config (skills, agents, AGENTS.md)
argument-hint: "[specific topic or \"all\" or \"--dry-run\"]"
---

Usage: /learn-opencode [specific topic or "all" or "--dry-run"]

$ARGUMENTS

Analyze the current conversation for reusable learnings and update the relevant OpenCode configuration files.

## Workflow

1. Load the **meta-skill-learnings** and **meta-opencode-authoring** skills in parallel

2. Scan the conversation for:
   - Bug patterns discovered during debugging
   - Gotchas or pitfalls encountered
   - New conventions established
   - Anti-patterns identified
   - Useful workflows that should be documented
   - Tool usage patterns worth remembering
   - Decisions that should become permanent rules

3. For each learning, determine where it belongs:
   - **Skill update** — if it's domain-specific knowledge (e.g., a React gotcha -> `review-frontend`)
   - **Agent update** — if it changes how an agent should behave
   - **AGENTS.md update** — if it's a universal rule that applies across all tasks
   - **New skill** — if no existing skill covers the domain (rare — prefer updating existing)

4. Present the learnings to the user:
   - Show each learning with its proposed destination
   - Let the user approve, modify, or reject each one

5. Write a spec file to `plans/learn-opencode-<YYYY-MM-DD>.md` with all findings:

   ```markdown
   # Learnings from <date>

   ## Applied

   1. **[destination file/skill]**: [description of what was learned and added]

   ## Rejected

   1. **[destination file/skill]**: [description] — Reason: [user's reason]

   ## Skipped

   1. **[description]** — no clear destination
   ```

   If the file already exists (multiple runs on same day), append a numeric suffix (e.g., `learn-opencode-2025-01-15-2.md`).

6. Apply approved learnings (unless `--dry-run`):
   - Edit the relevant files directly
   - Follow the conventions from **meta-skill-learnings**

## Dry Run Mode

If `$ARGUMENTS` contains `--dry-run`:
- Generate the spec file in `plans/` with all findings
- Do NOT apply any changes to config files
- Report the spec file path so the user can review before applying

## Rules

- Never duplicate knowledge that already exists in a skill
- Prefer updating existing skills over creating new ones
- Keep learnings concise and actionable — not paragraphs of explanation
- If `$ARGUMENTS` is "all", extract everything. If a topic is specified, focus on that domain only.
- Always generate the spec file, even when applying changes (serves as a record)
