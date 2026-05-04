# OpenCode Config Improvements

**Scope**: `src/opencode/` — agents, commands, skills, AGENTS.md
**Date**: 2026-05-04
**Findings**: 14

---

## Top 3 Quick Wins

1. **Sync AGENTS.md config tree with reality** — the embedded directory listing is severely outdated (missing 20+ commands, 2 agents, many skills). Causes confusion when agents read it. (Small effort, High impact)
2. **Remove stale skills from AGENTS.md listing** — `comm-caveman`, `comm-fsrs`, `strategy-usefulness-checker`, `tool-sqlite-local-sync` appear in AGENTS.md but don't exist on disk (or vice versa). (Small effort, High impact)
3. **Add missing `specify-*` commands to taxonomy** — `specify-ci`, `specify-fix`, `specify-optimize`, `specify-reuse`, `specify-opencode`, `specify-agents-md`, `specify-tutorial`, `specify` are on disk but not in AGENTS.md's command list. (Small effort, Medium impact)

---

## Consistency

### 1. AGENTS.md config tree is stale
- **Files**: `src/opencode/AGENTS.md` lines 27-132
- **Current state**: Lists 9 agents (missing `critic.md`, `fullstacker.md`), ~35 commands (actual: 43), and skills that include deprecated entries (`comm-caveman`, `comm-fsrs`, `strategy-usefulness-checker`, `tool-sqlite-local-sync`) while missing real ones (`tool-local-ai`, `tool-posthog-cli`, `tool-psql`, `review-backend`)
- **Effort**: Small | **Impact**: High
- **Fix**: Regenerate the tree from actual disk contents. Consider auto-generating this section via a script.

### 2. Command taxonomy table incomplete
- **Files**: `src/opencode/AGENTS.md` line 139-150
- **Current state**: Table lists `clarify-*` prefix but no `clarify-*.md` commands exist on disk (only `clarify.md`). Missing entries for newer prefixes or unprefixed commands like `fms`, `quiz`, `structure`, `migration-check`, `review-plans`, `merge-specs`.
- **Effort**: Small | **Impact**: Medium
- **Fix**: Add a row for "utility" unprefixed commands listing examples, and remove `clarify-*` row or note it's currently unused.

### 3. AGENTS.md duplicated across global and repo
- **Files**: `src/opencode/AGENTS.md`, `dotfiles/AGENTS.md`
- **Current state**: The meta-agents-md skill says "Critical Code Writing Rule" and "Universal Rules" are duplicated for non-OpenCode tools. But syncing manually is error-prone.
- **Effort**: Medium | **Impact**: Low
- **Fix**: Accept duplication as intentional (for non-OpenCode tools like Cursor/Copilot). Add a comment at top of repo AGENTS.md: "Synced from src/opencode/AGENTS.md — keep in sync".

---

## Coverage Gaps

### 4. No `improve-*` commands on disk
- **Files**: `src/opencode/command/`
- **Current state**: AGENTS.md lists `improve-agents-md`, `improve-consolidate`, `improve-optimize`, `improve-security` but none exist on disk. The taxonomy says `improve-*` "finds issues and applies fixes/improvements".
- **Effort**: Medium | **Impact**: Medium
- **Fix**: Either create these commands or remove them from AGENTS.md. If they were deprecated, move the AGENTS.md references to a "deprecated" note.

### 5. No `fix-ci` or `fix-comments` commands on disk
- **Files**: `src/opencode/command/`
- **Current state**: AGENTS.md references these but they're not present on disk.
- **Effort**: Small | **Impact**: Medium
- **Fix**: Same as above — create or remove from AGENTS.md.

### 6. No skill for CI/CD patterns
- **Current state**: `specify-ci` command exists but no `ci` or `tool-ci` skill provides knowledge about CI patterns, GitHub Actions, etc.
- **Effort**: Medium | **Impact**: Medium
- **Fix**: Create a `tool-github-actions` or `ci` skill covering workflow patterns, caching, matrix builds, etc.

### 7. No `implement-jira` command on disk
- **Files**: `src/opencode/command/`
- **Current state**: AGENTS.md lists it but it doesn't exist. Only `specify-jira.md` and `tutorial-implement-jira.md` exist.
- **Effort**: Small | **Impact**: Low
- **Fix**: Remove from AGENTS.md or create the command.

---

## Redundancy

### 8. Parallelization section in AGENTS.md duplicates meta-parallelization skill
- **Files**: `src/opencode/AGENTS.md` lines 152-176, `skills/meta-parallelization/`
- **Current state**: Nearly identical content exists in both places.
- **Effort**: Small | **Impact**: Low
- **Fix**: Keep AGENTS.md version (it's always loaded). Skill can provide deeper examples for agents that need more guidance. Add cross-reference.

### 9. `specify-*` and `pr-*` convention sections are large
- **Files**: `src/opencode/AGENTS.md` lines 178-225
- **Current state**: These shared conventions are useful but bloat the always-loaded instructions. Commands that use them load it regardless.
- **Effort**: Medium | **Impact**: Low
- **Fix**: Acceptable as-is since commands reference them. No action needed unless AGENTS.md grows further.

---

## Clarity

### 10. Unprefixed commands lack discoverability
- **Files**: `fms.md`, `quiz.md`, `structure.md`, `migration-check.md`, `review-plans.md`, `merge-specs.md`
- **Current state**: These don't fit the taxonomy. Users won't know they exist without listing all commands.
- **Effort**: Small | **Impact**: Medium
- **Fix**: Either rename with prefixes (e.g., `specify-structure`, `review-plans` -> `specify-plans`) or document them explicitly in a "Utility Commands" section of AGENTS.md.

### 11. `fms` command name is cryptic
- **Files**: `src/opencode/command/fms.md`
- **Current state**: Abbreviation is non-obvious. Users and agents can't guess what it does from the name alone.
- **Effort**: Small | **Impact**: Medium
- **Fix**: Rename to something descriptive, or add it to a documented abbreviations table.

---

## Ergonomics

### 12. Too many `specify-*` commands (14 on disk)
- **Files**: `src/opencode/command/specify-*.md`
- **Current state**: 14 specify commands make `/specify` tab-completion noisy. Hard to remember which one to use.
- **Effort**: Large | **Impact**: Medium
- **Fix**: Consider a single `/specify` command that accepts a category argument (e.g., `/specify security`, `/specify quality`). The `specify.md` command may already do this — if so, the individual ones could be deprecated.

### 13. `specify.md` may make individual specify commands redundant
- **Files**: `src/opencode/command/specify.md` vs `specify-*.md`
- **Current state**: If `specify.md` is a meta-command that routes to categories, the individual files may be unnecessary overhead.
- **Effort**: Medium | **Impact**: Medium
- **Fix**: Review `specify.md` content. If it handles routing, deprecate individual commands. If not, consider making it do so.

---

## Effectiveness

### 14. `opencode.json` has trailing comma (invalid JSON)
- **Files**: `src/opencode/opencode.json` line 62
- **Current state**: `"enabled": false,` has a trailing comma before `}`. This is technically invalid JSON (though many parsers tolerate it).
- **Effort**: Small | **Impact**: Low
- **Fix**: Remove the trailing comma.
