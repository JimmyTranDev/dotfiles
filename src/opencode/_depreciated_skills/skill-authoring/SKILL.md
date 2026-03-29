---
name: skill-authoring
description: How to write effective OpenCode agent skills with proper naming, frontmatter, and domain-scoped content
---

## What Skills Are

Skills are reusable knowledge documents loaded on-demand via the `skill` tool. Agents see a list of available skills (name + description) and can load the full content when relevant. Each skill lives at `skills/<name>/SKILL.md`.

## File Format

```markdown
---
name: skill-name
description: One-line summary of what knowledge this skill provides
---

## Section 1
Content organized by topic.

## Section 2
More content. Use tables, code blocks, and lists.
```

## Discovery Locations

- Global: `~/.config/opencode/skills/<name>/SKILL.md`
- Project: `.opencode/skills/<name>/SKILL.md`

Skills are auto-discovered — they do NOT need to be listed in `opencode.json`.

## Required Frontmatter

| Field | Rule |
|-------|------|
| `name` | 1-64 chars, lowercase alphanumeric, single-hyphen separators, matches directory name |
| `description` | 1-1024 chars, specific enough for an agent to decide when to load it |

## Optional Frontmatter

| Field | Purpose |
|-------|---------|
| `license` | License identifier (e.g., `MIT`) |
| `compatibility` | Tool compatibility (e.g., `opencode`) |
| `metadata` | String-to-string map for custom metadata |

## Name Validation

Must match: `^[a-z0-9]+(-[a-z0-9]+)*$`

- Lowercase alphanumeric with single hyphens
- No leading/trailing hyphens
- No consecutive hyphens (`--`)
- Must match the containing directory name

Good: `git-workflows`, `react-patterns`, `shell-scripting`
Bad: `Git-Workflows`, `react_patterns`, `my--skill`

## Description Writing

The description appears in the skill tool's available skills list. It must be specific enough for an agent to decide whether to load the skill for the current task.

Good:
- "Branch naming, commit conventions, PR workflows, and base branch strategy"
- "Shell scripting conventions for bash and zsh including error handling, naming, color output, and module patterns"

Bad:
- "Git stuff" (too vague, agent can't decide when to load it)
- "Everything you need to know about React" (too broad, no specifics)

## Content Principles

### Domain-Scoped
Each skill covers one domain. Don't mix unrelated topics. If a skill covers "TypeScript patterns" it should not also cover commit conventions.

### No Duplication Across Skills
Shared conventions (module structure, naming, no-comments rule) belong in one skill (e.g., `code-style-guide`). Domain skills should only contain domain-specific additions.

Before adding content, check: "Does this already exist in another skill?" If yes, don't repeat it.

### Actionable Over Theoretical
Include concrete patterns, code examples, decision trees, and lookup tables. Avoid paragraphs of theory.

Good:
```markdown
| Content | File |
|---------|------|
| TypeScript type/interface | `types.ts` |
| Constant, enum, or config value | `consts.ts` |
```

Bad:
```markdown
When organizing TypeScript modules, it's important to consider the separation
of concerns and ensure that each file has a single responsibility...
```

### Code Examples
Use realistic code from actual projects. Keep examples short (3-10 lines). Show the pattern, not a full implementation.

## Content Structure

Use `##` headers to organize by topic. Common patterns:
- **Tables** for lookup/reference data (naming conventions, emoji mappings, aliases)
- **Code blocks** for patterns and examples
- **Bullet lists** for rules and conventions
- **Decision trees** for "where does X go?" questions

## Quality Checklist

- [ ] Name matches directory name and passes regex validation
- [ ] Description lists specific topics covered (not just the domain name)
- [ ] Content is domain-scoped — no bleed into other skills
- [ ] No duplication of content from other skills
- [ ] Examples use realistic code, not toy examples
- [ ] Tables and code blocks preferred over prose
