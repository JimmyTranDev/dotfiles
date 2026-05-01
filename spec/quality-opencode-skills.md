# Quality: OpenCode Skills

Scope: `src/opencode/skills/` (74 directories)

## High Severity

### 1. Missing SKILL.md — Empty Skill Directories

| Skill | Issue | Fix |
|-------|-------|-----|
| `strategy-usefulness-checker/` | Directory exists but contains no SKILL.md | Create SKILL.md or remove directory |
| `tool-sqlite-local-sync/` | Directory exists but contains no SKILL.md | Create SKILL.md or remove directory |

Principle violated: **Dead code** — empty directories pollute discovery and confuse agents scanning available skills.

---

### 2. Stale Cross-References in ui-designer

**File**: `ui-designer/SKILL.md:6`

```
For accessibility, see the `accessibility` skill. For animations, see the `ux-ui-animator` skill.
```

- `accessibility` should be `ui-accessibility`
- `ux-ui-animator` should be `ui-animator`

**Fix**: Replace with correct skill names.

---

### 3. Stale Cross-Reference in ui-accessibility

**File**: `ui-accessibility/SKILL.md:142`

```
(see `ux-ui-animator` skill for implementation patterns)
```

- `ux-ui-animator` should be `ui-animator`

**Fix**: Replace with `ui-animator`.

---

## Medium Severity

### 4. specify-test Violates Analysis-Only Convention

**File**: `specify-test/SKILL.md:16`

```
This category actually writes tests (not purely analysis-only):
```

The `specify-*` convention in AGENTS.md states these commands are analysis-only and only create spec files. This skill explicitly contradicts that.

**Fix**: Rewrite to be analysis-only (identify coverage gaps, write findings to spec file). Move test-writing behavior to a separate `implement-test` or `tutorial-test` workflow.

---

### 5. meta-parallelization Duplicates AGENTS.md Content

The `meta-parallelization` skill content is nearly identical to the "Parallelization" section already injected via AGENTS.md into every conversation. Loading this skill adds redundant tokens.

**Fix**: Either (a) remove the parallelization section from AGENTS.md and rely on skill loading, or (b) reduce the skill to a brief note that rules are already injected via AGENTS.md.

---

## Low Severity

### 6. Excessive Skill Length

| Skill | Lines | Note |
|-------|-------|------|
| `tool-spring-boot` | ~1143 | Overlaps with `java-spring-senior` (~807 lines) |
| `ui-animator` | ~695 | Comprehensive but context-heavy |

**Fix**: Consider splitting into focused sub-skills or trimming to essential patterns only.

---

### 7. Inconsistent Opening Structure

~7 skills use a prose paragraph after frontmatter instead of jumping to `##` headers (`security`, `strategy-engager`, `strategy-innovate`, `ui-designer`, `ui-animator`, `tool-psql`, `tool-local-ai`). Most skills start with `##` immediately.

**Fix**: Minor — standardize to `##` headers first for consistency.

---

## Summary

| Severity | Count |
|----------|-------|
| High | 3 (2 missing files, 3 stale refs) |
| Medium | 2 |
| Low | 2 |
| **Total** | **7** |
