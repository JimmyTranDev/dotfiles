---
name: specify-opencode
description: Specify skill for OpenCode config analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`opencode-`

## Skills to Load

- **meta-opencode-authoring**: How to write agents, commands, and skills
- **meta-agents-md**: AGENTS.md structure and conventions
- **code-deduplicator**: Find redundancy across config files
- **code-follower**: Match existing conventions

## Agents to Launch

None specified.

## Analysis Categories

- **Coverage gaps**: Workflows that no command handles, domains no skill covers, situations no agent is suited for
- **Clarity**: Descriptions too vague for correct routing, names that are confusing or non-obvious, commands that are hard to discover
- **Consistency**: Files that break conventions others follow — wrong frontmatter, missing sections, different levels of detail
- **Redundancy**: Knowledge duplicated across files — commands inlining skill content, agents repeating AGENTS.md rules, skills overlapping
- **Ergonomics**: Names that are hard to remember, taxonomy that's unintuitive, too many steps for common operations
- **Effectiveness**: Agent prompts that produce poor outputs, command workflows that miss edge cases, skills with outdated patterns

### Config State Scanning

- Read `src/opencode/AGENTS.md` for global rules
- List all agents in `src/opencode/agent/`
- List all commands in `src/opencode/command/`
- List all skills in `src/opencode/skills/`

## Severity Classification

Rank by impact-to-effort ratio:
- **High impact / Low effort**: Quick wins
- **High impact / Medium effort**: Important improvements
- **Medium impact**: Consistency fixes
- **Low impact**: Polish

## Scope Overrides

None — uses default scope detection.
