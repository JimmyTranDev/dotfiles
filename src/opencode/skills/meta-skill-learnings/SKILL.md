---
name: meta-skill-learnings
description: Workflow for improving OpenCode skills directly when discovering bugs, gotchas, pitfalls, anti-patterns, or missing patterns during code review and analysis
---

## When to Improve Skills

After any review, analysis, audit, fix, or investigation that surfaces a reusable insight — a bug pattern, gotcha, pitfall, anti-pattern, missing edge case, or best practice not yet captured in existing skills.

Do NOT record learnings to a separate file. Instead, improve the relevant skill directly so the knowledge is immediately available for future tasks.

## Decision: Improve Existing Skill vs Create New Skill

| Condition | Action |
|-----------|--------|
| Insight fits an existing skill's domain | Add to that skill |
| Insight spans multiple existing skills | Add to the most relevant one, cross-reference from others |
| Insight covers a new domain not in any skill | Create a new skill (load **meta-opencode-authoring** first) |
| Insight is project-specific, not generalizable | Skip — do not pollute skills with one-off fixes |

## How to Improve an Existing Skill

1. Identify which skill the learning belongs to by matching the domain
2. Read the current skill file
3. Find the most relevant section (or add a new `##` section if none fits)
4. Add the insight using the skill's existing format — match the style (tables, code blocks, bullet lists)
5. Keep additions concise: pattern name, what goes wrong, how to fix it
6. Do not duplicate content already present in the skill

## Format for Added Patterns

Use the format that matches the skill's existing style. Common formats:

### Table row (for skills using tables)
```
| Pattern name | What goes wrong | Fix |
```

### Code block (for skills with code examples)
```
BAD:  <code that causes the issue>
GOOD: <code that avoids it>
```

### Bullet point (for skills using lists)
```
- **Pattern name**: Description of the pitfall and how to avoid it
```

## What Qualifies as a Skill Improvement

- Bug pattern that could recur (e.g., "missing await in error handler")
- Gotcha specific to a framework or library version
- Anti-pattern found in real code that existing skill rules don't catch
- Missing edge case category in a review/analysis checklist
- Best practice discovered during investigation that should be standard

## What Does NOT Qualify

- One-off bugs with no generalizable lesson
- Project-specific business logic
- Preferences or style opinions not backed by correctness/reliability reasoning
- Patterns already covered by existing skill content
