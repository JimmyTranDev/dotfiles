# OpenCode Config: Improvements & Simplifications

## Critical: Fix Broken References

### Task 1: Fix dead agent references in commands
- `command/pr-parallel.md:39` references **general** agent — does not exist, replace with **implementer**
- `command/pr-multiple.md:41` references **general** agent — replace with **implementer**
- `command/pr-multiple.md:22` references **explore** agent — does not exist, remove or replace with Task tool explore pattern

### Task 2: Fix dead command references in scan outputs
- `command/scan-useful.md:41` suggests `/design` — does not exist, change to `/scan-design`
- `command/scan-innovate.md:31` suggests `/design` — change to `/scan-design`
- `command/scan-innovate.md:31` suggests `/improve` — change to `/improve-consolidate` or remove
- `command/scan-quality.md:46` suggests `/consolidate` — change to `/improve-consolidate`

### Task 3: Fix broken skill cross-references
- `skills/ui-designer/SKILL.md` references "accessibility skill" — change to **ui-accessibility**
- `skills/ui-designer/SKILL.md` references "ux-ui-animator skill" — change to **ui-animator**
- `skills/ui-accessibility/SKILL.md` references "ux-ui-animator skill" — change to **ui-animator**
- `skills/security/SKILL.md` references "npm-vulnerabilities skill" — change to **security-npm-vulnerabilities**
- `skills/code-simplifier/SKILL.md` references "deduplicator", "consolidator" — change to **code-deduplicator**, **code-consolidator**

### Task 4: Fix skill loading reference in fix-comments
- `command/fix-comments.md:48` references "commit format from the **git-workflows** skill" but never loads it — add to skill loading section at line 37-39

---

## High: Remove Stale/Duplicate Content

### Task 5: Remove config structure tree from AGENTS.md
Remove lines 20-122 (the full directory tree). It's 100+ lines that drift constantly. Keep only the 4 bullet-point explanations at lines 125-128. The LLM sees the actual filesystem — this tree adds no value and actively misleads when stale.

### Task 6: Remove phantom entries from AGENTS.md
- Remove `strategy-usefulness-checker` from skills list (directory exists but no SKILL.md)
- Remove `tool-sqlite-local-sync` from skills list (directory exists but no SKILL.md)
- Remove `scan.md` from commands list (does not exist)
- Remove `clean-worktrees.md` from commands list (replaced by `clean-all.md` + `clean-merged.md`)

### Task 7: Delete meta-parallelization skill
`skills/meta-parallelization/SKILL.md` duplicates the Parallelization section already in AGENTS.md (which is always loaded). The skill is never referenced by any agent or command. Delete the directory.

---

## High: Fix Naming Convention Violation

### Task 8: Rename scan-test to improve-test
`command/scan-test.md` writes tests (line 34: "Write tests"), violating the `scan-*` taxonomy rule ("Makes Changes? No"). Rename to `improve-test.md` and update its description.

---

## High: Standardize Commit Format

### Task 9: Pick one commit format and apply everywhere
Two formats exist across commands:
- **Format A** (emoji first): `<emoji> <type>(<scope>): <description>` — used in `pr.md:35`, `pr-sequential.md:55`, `implement-sequential.md:47`, `pr-bump.md:32`, `pr-audit.md:42`
- **Format B** (type first): `<type>(<scope>): <emoji> <description>` — used in `commit.md:8`, `pr-parallel.md:43`

Pick one format and update all commands to match. Also remove the inline commit emoji table from `pr-parallel.md:47-60` — reference the canonical format from `commit.md` or `git-workflows` skill instead.

---

## Medium: Consolidate Duplicate Commands

### Task 10: Merge clean-all + clean-merged into single clean command
Create `command/clean.md` that asks the user "Clean only merged branches, or all?" via the question tool. Delete `clean-all.md` and `clean-merged.md`. Add `clean-*` to the taxonomy table or use the no-prefix utility category.

### Task 11: Deduplicate pr-sequential and implement-sequential
The inner task loop (implement → review → fix → commit → update PR → todoist) is copy-pasted between these two commands. Options:
- Make `implement-sequential` accept a `--pr` flag
- Extract the shared loop into a description both commands reference
- Have `pr-sequential` delegate to `/implement-sequential` after worktree setup

### Task 12: Deduplicate tutorial-implement-jira and tutorial
`tutorial-implement-jira.md` copies tutorial steps instead of delegating. Restructure so it fetches the Jira ticket (steps 1-4) then says "Follow the `/tutorial` command workflow with this context."

### Task 13: Consider merging scan-review and scan-logic
Both load nearly identical skills and delegate to the same agents. `scan-review` is a superset of `scan-logic`. Options:
- Merge into one command with an optional `--focus=logic` flag
- Keep both but remove overlapping categories from `scan-logic`

---

## Medium: Agent Consistency

### Task 14: Add missing "When to Use" sections
- `agent/fixer.md` — add "When to Use Fixer (vs Reviewer, Implementer)"
- `agent/optimizer.md` — add "When to Use Optimizer (vs Implementer, Fixer)"
- `agent/tester.md` — add "When to Use Tester (vs Reviewer, Fixer)"

### Task 15: Remove security overlap from reviewer
`agent/reviewer.md:24` lists "security vulnerabilities" as something it checks. This is the auditor's job. Remove it from reviewer and add a note: "For security concerns, recommend running the auditor."

### Task 16: Standardize agent skills section format
Three patterns exist for declaring skills:
1. Standalone `## Skills` section (fixer, optimizer, reviewer, tester)
2. Embedded in `## How You Work` (designer, git, implementer)
3. Inline in prose (auditor, engager)

Standardize on standalone `## Skills` for all agents.

---

## Medium: Skill Cleanup

### Task 17: Delete phantom skill directories
- Delete `skills/strategy-usefulness-checker/` (no SKILL.md)
- Delete `skills/tool-sqlite-local-sync/` (no SKILL.md)

### Task 18: Consider merging code-deduplicator into code-simplifier
`code-deduplicator` (72 lines) is one section of `code-simplifier` (341 lines). Merge and update all references.

---

## Low: Minor Consistency Fixes

### Task 19: Fix improve-optimize skill loading placement
`command/improve-optimize.md` places skill/agent section at the end (step 7, lines 41-49) after work is done. Move to the beginning like other commands.

### Task 20: Add agent delegation to scan-design and scan-engage
These are the only `scan-*` commands that don't delegate to any agents, breaking the pattern. Add **reviewer** delegation or document why they're excluded.

### Task 21: Add skill loading to scan-innovate and scan-useful
These are the only `scan-*` commands that load zero skills. Consider loading **code-follower** at minimum for consistency, or **strategy-innovate** / **strategy-usefulness-checker** if those skills are created.

### Task 22: Add taxonomy entries for new prefixes
Add to the AGENTS.md taxonomy table:
- `clean-*` — Clean up worktrees, branches, or other artifacts — Yes
- `verify-*` — Check files against rules (read-only unless user opts in) — No

Decide on taxonomy for `specify`, `fill`, `caveman` (utility/no-prefix).

---

## Low: Prune Unused Skills (Optional)

12 skills are never referenced by any agent or command. They're only usable on-demand. Consider whether to keep for manual use or prune:

| Skill | Lines | Decision needed |
|-------|-------|-----------------|
| `tool-posthog-cli` | 105 | Just added — keep |
| `tool-drizzle-orm` | 516 | Keep if used in projects |
| `tool-slack-cli` | 238 | Keep if used in projects |
| `tool-knip` | 226 | Keep if used in projects |
| `tool-storybook-mcp` | 121 | Keep if used in projects |
| `tool-spring-boot` | 1143 | Keep if used in projects |
| `mcp-browser` | 221 | Keep if used in projects |
| `mcp-mobile` | 187 | Keep if used in projects |
| `comm-fsrs` | 86 | Rarely used — prune candidate |
| `comm-spec-writer` | 124 | Rarely used — prune candidate |
| `comm-doc-writer` | 138 | Rarely used — prune candidate |
| `test-android-db-inspector` | 131 | Rarely used — prune candidate |
