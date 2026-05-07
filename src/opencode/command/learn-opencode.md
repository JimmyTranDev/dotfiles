---
name: learn-opencode
description: Extract learnings from the current chat and update OpenCode config (skills, agents, AGENTS.md)
---

Usage: /learn-opencode [specific topic or "all"]

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
   - **Skill update** — if it's domain-specific knowledge (e.g., a React gotcha → `review-frontend`)
   - **Agent update** — if it changes how an agent should behave
   - **AGENTS.md update** — if it's a universal rule that applies across all tasks
   - **New skill** — if no existing skill covers the domain (rare — prefer updating existing)

4. Present the learnings to the user:
   - Show each learning with its proposed destination
   - Let the user approve, modify, or reject each one

5. Apply approved learnings:
   - Edit the relevant files directly
   - Follow the conventions from **meta-skill-learnings**

## Rules

- Never duplicate knowledge that already exists in a skill
- Prefer updating existing skills over creating new ones
- Keep learnings concise and actionable — not paragraphs of explanation
- If `$ARGUMENTS` is "all", extract everything. If a topic is specified, focus on that domain only.
