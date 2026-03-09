---
name: agents-md
description: Structure, conventions, and update workflow for AGENTS.md files that control AI agent behavior
---

## What AGENTS.md Is

AGENTS.md files provide persistent instructions that are injected into every AI agent conversation. They control coding style, conventions, and behavioral rules across all interactions.

## File Locations

| Location | Scope | Loaded By |
|----------|-------|-----------|
| `~/.config/opencode/AGENTS.md` | Global OpenCode rules | `opencode.json` `instructions` array |
| `<repo>/AGENTS.md` | Repo-specific context | Auto-discovered by AI tools at repo root |
| `<repo>/<subdir>/AGENTS.md` | Directory-scoped rules | Auto-discovered when working in that directory |

## Structure of Global AGENTS.md (`~/.config/opencode/AGENTS.md`)

This file contains rules that apply to every project:

| Section | Purpose |
|---------|---------|
| Critical Code Writing Rule | No-comments policy |
| Universal Rules | Convention matching, no docs creation, prefer editing, theme |
| Parallelization | Tool calls, skill loading, agent delegation, codebase exploration, git operations |

## Structure of Repo AGENTS.md (`<repo>/AGENTS.md`)

This file contains repo-specific context:

| Section | Purpose |
|---------|---------|
| Critical Code Writing Rule | Same no-comments policy (duplicated for non-OpenCode tools) |
| Universal Rules | Same core rules (duplicated for non-OpenCode tools) |
| Repository Structure | Directory tree with symlink destinations |
| How Symlinks Work | Platform detection, link targets |
| Working with This Repo | Adding configs, shell script conventions, OpenCode config structure |

## Content Principles

- **Concise directives** — write rules as short, imperative statements, not explanations
- **No duplication across skills** — AGENTS.md holds cross-cutting rules; domain-specific knowledge belongs in skills
- **Tables over prose** — use tables for structured reference data
- **Behavioral rules only** — AGENTS.md controls how agents behave, not domain knowledge

## When to Update

- Adding a new cross-cutting coding rule (applies to all projects)
- Changing parallelization strategy
- Adding a new universal convention
- Updating repo structure after adding/removing configs
- Changing the symlink mapping or install flow

## Update Workflow

1. Determine which AGENTS.md to update:
   - Global rules that apply everywhere -> `~/.config/opencode/AGENTS.md`
   - Repo-specific structure/context -> `<repo>/AGENTS.md`
   - Both share the "Critical Code Writing Rule" and "Universal Rules" sections — keep them in sync

2. Read the current file to understand existing structure and avoid duplication

3. Apply changes:
   - Add new sections with `##` headers
   - Keep rules as bullet points or tables
   - Preserve existing section ordering
   - Do not duplicate content that belongs in a skill

4. If both files share a section (e.g., Universal Rules), update both to stay in sync

## What Does NOT Belong in AGENTS.md

| Content | Where It Belongs |
|---------|-----------------|
| Commit message format, emoji mapping | `git-workflows` skill |
| TypeScript patterns, error handling | `typescript-patterns` skill |
| React component conventions | `react-patterns` skill |
| Shell scripting conventions | `shell-scripting` skill |
| File organization rules | `file-organizer` skill |
| Worktree lifecycle | `worktree-workflow` skill |
