## Overview

Quality deduplication pass across `src/opencode/skills/`. The collection is already well-factored — recent refactoring (commits `beeaeaf`, `7fa4404`) extracted shared conventions into AGENTS.md and consolidated command families. Only 4 minor issues remain: one verbatim duplicate block, two missing skill cross-references, and two empty skill directories.

## Architecture

Skills are auto-discovered markdown files at `skills/<name>/SKILL.md`. The `specify-*` skills are thin dispatch templates that list analysis categories and reference deeper skills via "Skills to Load". AGENTS.md centralizes shared conventions (`specify-*` scope detection, spec output, PR rules). This layered design means specify-* files should NOT duplicate content from the skills they load.

## Data flow

N/A — these are static markdown reference files, not runtime code.

## Tasks

### 1. Remove duplicated severity table from `specify-security/SKILL.md`
- **File**: `src/opencode/skills/specify-security/SKILL.md`
- **Change**: Remove the severity classification table (Critical/High/Medium/Low) — it's already present in `security/SKILL.md` which this skill loads
- **Complexity**: small
- **Parallel**: yes

### 2. Add `code-quality` to `specify-quality/SKILL.md` Skills to Load
- **File**: `src/opencode/skills/specify-quality/SKILL.md`
- **Change**: Add `code-quality` to the Skills to Load section. Currently loads code-simplifier, code-deduplicator, code-conventions but omits the hub skill for the domain
- **Complexity**: small
- **Parallel**: yes

### 3. Add `strategy-innovate` to `specify-innovate/SKILL.md` Skills to Load
- **File**: `src/opencode/skills/specify-innovate/SKILL.md`
- **Change**: Add `strategy-innovate` to the Skills to Load section (currently says "None required" despite a matching deep skill existing)
- **Complexity**: small
- **Parallel**: yes

### 4. Remove empty skill directories
- **Files**: `src/opencode/skills/strategy-usefulness-checker/`, `src/opencode/skills/tool-sqlite-local-sync/`
- **Change**: Delete these directories — they contain no SKILL.md and serve no purpose
- **Complexity**: small
- **Parallel**: yes

## API contracts

N/A

## State changes

None — only markdown file edits and directory removal.

## Edge cases

- Task 1: Verify `specify-security` actually lists `security` in its Skills to Load before removing the table. If it doesn't, add the reference instead of just deleting.
- Task 4: Confirm no other config references these empty directories before deleting.

## Testing approach

- After each edit, verify the skill still loads correctly in OpenCode (no frontmatter errors)
- Grep for any references to `strategy-usefulness-checker` or `tool-sqlite-local-sync` before deleting

## Open questions

### Scope
- **Empty dirs**: Were `strategy-usefulness-checker` and `tool-sqlite-local-sync` intentionally left empty as placeholders for future work? If so, keep them.
