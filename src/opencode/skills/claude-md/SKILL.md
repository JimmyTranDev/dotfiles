---
name: claude-md
description: Creates or updates a CLAUDE.md rules file (project or global) for opencode and Claude Code, including migrating a legacy AGENTS.md to CLAUDE.md — renaming the file and fixing opencode `instructions` arrays, `.gitignore` allowlists, and internal references. Use when adding agent/project rules to a repo that has none, editing an existing CLAUDE.md, or converting AGENTS.md → CLAUDE.md. Triggers on "create a CLAUDE.md", "update CLAUDE.md", "migrate AGENTS.md to CLAUDE.md", "add agent rules", "/claude-md". In this dotfiles repo edit the src/ source (e.g. src/claude/CLAUDE.md), never the live ~/.config or ~/.claude targets. Use ONLY for CLAUDE.md rules files — for a reusable skill use skill-authoring, for opencode.json/agents/plugins/MCP use customize-opencode.
---

# CLAUDE.md Rules File

## Overview

Creates or updates a `CLAUDE.md` — the markdown rules file opencode and Claude Code load as system instructions — for a project or the global scope, and migrates a legacy `AGENTS.md` to `CLAUDE.md` when one exists. This is the exact, repeatable routine; for the broader strategy of *what* belongs in a rules file, defer to `context-engineering`.

## Background: how the rules file is loaded

- **Claude Code** reads `CLAUDE.md` natively — project root(s) and `~/.claude/CLAUDE.md` globally.
- **opencode** reads `AGENTS.md` first and treats `CLAUDE.md` as a *fallback*: if both exist in the same scope, `AGENTS.md` wins and `CLAUDE.md` is ignored. Migrating therefore means **renaming or removing** `AGENTS.md`, never leaving both.
- opencode also loads any file named in an `opencode.json` / `opencode.jsonc` `instructions` array, resolved relative to that config file's directory.

## When to Use

- Standing up agent rules for a repo that has none ("add agent rules", "create a CLAUDE.md").
- Editing an existing `CLAUDE.md`.
- Migrating `AGENTS.md` → `CLAUDE.md` (rename plus reference updates).

**Do NOT use when:**

- Authoring a reusable skill — use `skill-authoring`.
- Editing `opencode.json`, agents, plugins, or MCP config — use `customize-opencode`.
- The task is unrelated to a rules file's content or filename.

## The Workflow

### 1. Survey the current state

Run `git grep -n -I 'AGENTS\.md'` (and `CLAUDE\.md`) and locate every rules file and reference:

- `AGENTS.md` / `CLAUDE.md` files — root and nested (e.g. `.opencode/`, `packages/*`, `apps/*`).
- `instructions` arrays in every `opencode.json` / `opencode.jsonc`.
- `.gitignore` allowlist lines (`!AGENTS.md`).
- Internal references in commands, skills, scripts, docs, and specs.

Decide the mode: **migrate** (an `AGENTS.md` exists) or **create** (none exists).

### 2a. Migrate — rename each AGENTS.md

For every project-scope `AGENTS.md`:

1. `git mv <path>/AGENTS.md <path>/CLAUDE.md` — preserves history; never delete-and-recreate.
2. Fix the file's own title / self-reference (e.g. `# AGENTS.md` → `# CLAUDE.md`, and prose like `instructions: ["AGENTS.md"]`).
3. Point the matching `instructions` array at `CLAUDE.md`.

**Duplicate / global file:** if an `AGENTS.md` is byte-identical (`diff -q`) to a canonical `CLAUDE.md` elsewhere, **delete** it instead of renaming and let the canonical file be the single source — then drop its now-dangling `instructions` entry (rely on auto-load, or add an explicit path only if the probe in step 5 shows the rules don't load). **Caveat:** `diff -q` also reports a *symlink* as identical to its target, so before deleting confirm the file is genuinely separate — a `CLAUDE.md` that already symlinks to the canonical one (e.g. `src/claude/CLAUDE.md` → `../opencode/CLAUDE.md`) must be left in place, not deleted.

### 2b. Create — scaffold a new CLAUDE.md

Write `CLAUDE.md` with the project's universal rules, structure, and conventions (see `context-engineering` for what belongs). Wire it into the nearest `opencode.json` `instructions` array if the project uses opencode config.

### 3. Update every reference

- `.gitignore` allowlist: `!AGENTS.md` → `!CLAUDE.md`.
- Internal references in commands / skills / scripts / docs / specs → `CLAUDE.md`.
- Config validators / health checks that hardcode the filename.

### 4. Dotfiles-repo caveat

In this dotfiles repo the rules files are symlink **sources**: edit under `src/` (e.g. `src/claude/CLAUDE.md`), never the live `~/.config` or `~/.claude` targets, and keep `sync_links.sh` ↔ `doctor.sh` in sync.

### 5. Verify

- `git grep -n 'AGENTS\.md'` returns only intentional / historical references.
- Any config validator (e.g. `validate-opencode.sh`) passes.
- opencode still loads the rules — confirm the expected rules appear (probe a fresh session, or confirm the resolved instruction file exists at its path). Do not assume; verify.

## Rules

- Rename with `git mv`; never delete-and-recreate a tracked rules file.
- Never leave both `AGENTS.md` and `CLAUDE.md` in the same directory — opencode ignores the `CLAUDE.md`.
- In this dotfiles repo, edit `src/` sources only, never live symlink targets.
- Update references and allowlists in the *same* change as the rename — a half-migrated repo silently loses its rules.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll keep AGENTS.md too, for safety." | opencode ignores `CLAUDE.md` when `AGENTS.md` exists — keeping both means your `CLAUDE.md` edits do nothing. Rename/remove the `AGENTS.md`. |
| "Deleting and recreating is simpler than git mv." | delete+create loses git history/blame. Always `git mv`. |
| "The rename is enough; refs can follow later." | A dangling `instructions` entry or a stale `!AGENTS.md` allowlist silently breaks rule-loading. Update refs in the same change. |
| "I'll just edit ~/.config/.../AGENTS.md directly." | In dotfiles those are symlinks; edit the `src/` source or the change is untracked and lost on relink. |
| "Empty instructions can't be right — I'll hardcode the CLAUDE.md path." | Only if auto-load fails. Verify the fallback first; add an explicit path/symlink only when the probe shows the rules aren't loaded. |

## Red Flags

- Both `AGENTS.md` and `CLAUDE.md` present in one directory after migration.
- `git status` shows `AGENTS.md` deleted + `CLAUDE.md` added as a brand-new untracked file (rename not detected → history lost).
- An `instructions` array still names `AGENTS.md`, or names a file that does not exist.
- `git grep 'AGENTS\.md'` still returns live references after a "complete" migration.
- Editing a file under `~/.config` / `~/.claude` in this dotfiles repo.

## Verification

- [ ] Every migrated `AGENTS.md` is now `CLAUDE.md` via `git mv` (rename shown in `git status` / `git diff --stat`).
- [ ] No directory contains both `AGENTS.md` and `CLAUDE.md`.
- [ ] Every `opencode.json` / `opencode.jsonc` `instructions` array points at an existing `CLAUDE.md`, or is intentionally empty relying on verified auto-load.
- [ ] `.gitignore` allowlists updated (`!CLAUDE.md`).
- [ ] Internal references (commands / skills / scripts / docs / specs) updated.
- [ ] `git grep -n 'AGENTS\.md'` returns only intentional references.
- [ ] opencode still loads the rules (verified, not assumed).
