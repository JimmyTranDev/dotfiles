---
name: specify-agents-md
description: Specify skill for AGENTS.md analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`agents-md-`

## Skills to Load

- **meta-agents-md**: AGENTS.md structure, content principles, and placement rules

## Agents to Launch

- **reviewer**: Verify proposed AGENTS.md content is accurate and follows conventions

## Analysis Categories

### Repo Scanning

- Read the repo root to identify major directories, languages, and frameworks
- Check for existing AGENTS.md files at all levels (root and subdirectories)
- Identify the tech stack from package.json, Cargo.toml, go.mod, pyproject.toml, or similar

### Placement Decision Tree

| Location | Create When |
|----------|-------------|
| Repo root `AGENTS.md` | Always — every repo benefits from root-level agent instructions |
| `src/AGENTS.md` or `app/AGENTS.md` | Main source directory has conventions not obvious from code alone |
| `<package>/AGENTS.md` | Monorepo packages with distinct tech stacks or conventions |
| `<subdir>/AGENTS.md` | Directory has unique rules that differ from the repo root |

Skip directories that:
- Are generated or vendored (`node_modules`, `dist`, `build`, `.next`, `vendor`)
- Already have an AGENTS.md that is complete and accurate
- Have fewer than 3 source files

### Content Extraction (per location)

- Repository or directory structure with purpose annotations
- Coding conventions actually used (naming, patterns, architecture)
- Tech stack and framework-specific patterns
- Build, test, and lint commands
- Import conventions and module boundaries
- Any non-obvious rules an agent would need to know

### AGENTS.md Drafting Rules

- Start with the no-comments policy if the repo follows it
- Use `##` section headers, bullet lists, and tables — no prose paragraphs
- Write rules as short imperative directives, not explanations
- Include a directory structure tree if the layout isn't self-evident
- Reference existing tooling (linters, formatters, test runners)
- Do not duplicate content that belongs in skills or that a parent AGENTS.md already covers
- Subdirectory AGENTS.md files should only contain rules specific to that directory

### Auto-Sync Check

- Verify every file and directory referenced in AGENTS.md actually exists
- Verify every directory tree matches the real structure
- Flag references to non-existent files, removed commands, deprecated skills, or stale paths
- Check that listed skills, commands, or agents still exist in their expected locations

### Existing File Audit

- Flag sections that are outdated (reference removed files, old patterns, wrong structure)
- Identify missing sections for conventions the file doesn't cover
- Identify inaccurate information that should be removed or updated

## Severity Classification

- **Critical**: Stale references, wrong information that would mislead agents
- **New file needed**: Location that would benefit from an AGENTS.md but doesn't have one
- **Minor improvement**: Existing AGENTS.md that could be enhanced

## Scope Overrides

None — uses default scope detection.
