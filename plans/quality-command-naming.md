# Improve Naming of OpenCode Commands

## Overview

The command directory has 28 commands. Most follow the established naming taxonomy (`fix-*`, `pr-*`, `implement-*`, `specify-*`, utility no-prefix), but several commands have names that don't clearly communicate their purpose or violate the taxonomy conventions. This spec proposes renames to improve discoverability and consistency.

## Architecture

Commands live at `src/opencode/command/*.md`. The filename becomes the slash-command name. The `name` field in frontmatter must match the filename (without `.md`). The AGENTS.md documents the taxonomy:

| Prefix | Purpose |
|--------|---------|
| `specify-*` | Analysis → spec files |
| `fix-*` | Diagnose and fix problems |
| `implement-*` | Build features |
| `pr-*` | Pull request workflows |
| `tutorial-*` | Step-by-step interactive |
| (no prefix) | Utility commands |

## Tasks

### 1. Rename `conflict.md` → `fix-conflict.md`

- **File**: `src/opencode/command/conflict.md`
- **Rationale**: Resolves conflict markers — this is a fix operation. The AGENTS.md already lists `fix-conflict.md` in the canonical command list, suggesting this was intended but the file wasn't renamed.
- **Changes**: Rename file, update `name` frontmatter to `fix-conflict`
- **Complexity**: small
- **Parallel**: yes

### 2. Rename `dependency.md` → `audit-deps.md` or keep as `dependency`

- **File**: `src/opencode/command/dependency.md`
- **Rationale**: "dependency" is a noun, not an action. The description says "Analyze dependencies for outdated packages, security issues, and unused exports." This is an analysis/audit utility.
- **Suggested name**: `audit-deps` (verb-first, concise) or `specify-deps` if it should produce a spec file
- **Complexity**: small
- **Parallel**: yes

### 3. Rename `triage.md` → `fix-triage.md` or keep as utility

- **File**: `src/opencode/command/triage.md`
- **Rationale**: "Walk through review findings one by one, decide actions, then execute." It both triages AND executes fixes, so `fix-*` prefix fits. However, it's also a workflow utility. Could stay as-is since it's unique.
- **Suggested name**: Keep `triage` — it's a distinct workflow pattern, not purely a fix
- **Complexity**: small
- **Parallel**: yes

### 4. Rename `triage-comments.md` → keep or consider `fix-comments`

- **File**: `src/opencode/command/triage-comments.md`
- **Rationale**: Similar to `triage` — walks through PR comments and handles them. Since it executes fixes, `fix-pr-comments` could work. But "triage" accurately describes the interactive decision workflow.
- **Suggested name**: Keep `triage-comments` — establishes `triage-*` as a pattern for interactive decision workflows
- **Complexity**: small
- **Parallel**: yes

### 5. Rename `opencode.md` → `init-opencode.md` or keep

- **File**: `src/opencode/command/opencode.md`
- **Rationale**: Description says "Analyze the current project, suggest agents/commands/skills, and create or update AGENTS.md." This overlaps with `init` conceptually. The name `opencode` is very generic.
- **Suggested name**: `setup-opencode` or `init-project` — but `init` already exists. Keep as `opencode` if it serves a different purpose than `init`.
- **Complexity**: small
- **Parallel**: yes

### 6. Rename `insight.md` — non-engineering command

- **File**: `src/opencode/command/insight.md`
- **Rationale**: "Generate a Dr. K-style insight about the mind, ego, and detachment." This is a personal/philosophical command, not engineering. Name is fine as a utility — no prefix needed.
- **Suggested name**: Keep `insight`
- **Complexity**: none (no change)

### 7. Validate `check-fix.md` name against taxonomy

- **File**: `src/opencode/command/check-fix.md`
- **Rationale**: Just created. It runs checks then fixes. Could be `fix-checks` (fix prefix since it fixes things) but `check-fix` reads naturally as "check, then fix."
- **Suggested name**: `fix-checks` to follow `fix-*` prefix convention, OR keep `check-fix` as a utility
- **Complexity**: small
- **Parallel**: yes

## Summary of Recommended Renames

| Current | Proposed | Reason |
|---------|----------|--------|
| `conflict.md` | `fix-conflict.md` | Matches taxonomy, already in AGENTS.md canonical list |
| `dependency.md` | `audit-deps.md` | Verb-first, clearer action |
| `check-fix.md` | `fix-checks.md` | Follows `fix-*` convention |

Commands to keep as-is: `triage`, `triage-comments`, `opencode`, `insight`, `explain`, `deploy`, all others already follow conventions.

## Resolved Questions

### Conventions
- Decision: Yes, `triage-*` is a new prefix for interactive walk-through workflows with decisions.
- Decision: Rename `check-fix` to `fix-checks` to follow `fix-*` convention.
- Decision: Rename `dependency` to `audit-deps` (new `audit-*` prefix for analysis without spec output).
- Decision: Keep `opencode` as-is — it's the "setup my OpenCode config for this project" command, broader than `init`.

### Scope
- Decision: Yes, update the AGENTS.md taxonomy table to document `triage-*` and `audit-*` prefixes.
- Decision: Just delete old files on rename — no redirect notes.
