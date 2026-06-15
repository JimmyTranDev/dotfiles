---
description: Run multiple specify-* analyses in parallel, producing one spec file per category in plans/
argument-hint: [--all] [category1 category2 ...] [scope or description]
---

Usage: /specify-parallel [--all] [category1 category2 ...] [scope or description]

Run multiple `specify-*` analyses simultaneously in parallel, each producing its own spec file in `plans/` at the project root. This command does NOT implement anything. It produces planning documents only.

$ARGUMENTS

1. Determine which categories to run from `$ARGUMENTS`:
   - If `--all` is present, run ALL 20 categories: agents-md, architecture, ci, comments, deploy, design, devtools, engage, fix, innovate, jira, migration, opencode, optimize, quality, reuse, review, security, test, tutorial
   - If specific categories are listed, run only those
   - Map synonyms/abbreviations using the same mapping as `/specify`:
     - `sec`, `vuln`, `vulnerabilities` → `security`
     - `perf`, `performance`, `speed` → `optimize`
     - `tests`, `coverage`, `testing` → `test`
     - `bugs`, `correctness`, `logic` → `review`
     - `code-quality`, `smells`, `refactor` → `quality`
     - `deps`, `dependencies`, `audit` → `security`
     - `ui`, `ux`, `accessibility`, `a11y` → `design`
     - `dx`, `tooling`, `linting` → `devtools`
     - `duplication`, `dry`, `dedup` → `reuse`
     - `structure`, `modules`, `coupling` → `architecture`
     - `ideas`, `features`, `brainstorm` → `innovate`
     - `engagement`, `retention`, `habits` → `engage`
     - `agents`, `agents.md` → `agents-md`
     - `bug`, `error`, `crash`, `broken` → `fix`
     - `pr-comments`, `feedback` → `comments`
     - `github-actions`, `pipeline`, `workflow` → `ci`
     - `steps`, `walkthrough`, `how-to` → `tutorial`
     - `ticket`, `jira` → `jira`
   - If no categories can be determined, present the full list of categories using the question tool and ask the user to pick which ones to run. Use `multiple: true` so the user can select multiple categories.
   - The remaining text after categories becomes the scope/description applied to all analyses

2. Before launching, present a confirmation to the user showing the selected categories and estimated total count. Allow the user to adjust (add/remove categories) before proceeding.

3. **Skill loading**: Load ALL relevant `specify-{category}` skills in a SINGLE parallel batch. Also load **meta-parallelization**.

4. Create the `plans/` directory at the project root if it doesn't exist.

5. Launch one agent per category in parallel — each agent runs independently and produces one spec file:

   For each category, the agent:
   a. Follows the `specify-*` conventions from AGENTS.md (scope detection, frontend/backend sanity check, analysis-only guard, spec file output)
   b. Loads its `specify-{category}` skill (already pre-loaded, but verifies it has the correct analysis categories, skill list, agent list, and severity classification)
   c. Writes a spec file to `plans/{category}-<descriptive-name>.md` following the naming convention
   d. Also produces a brief TL;DR to include in the aggregate summary: spec file path, total findings count, and top 3 most critical items

   Agents are fully independent — a failure in one category does not block others.

6. Collect results from all parallel agents. If all agents failed, report the failures and stop.

7. Present the aggregate summary:
   - Table showing each category, its spec file path, total findings, top critical item, and status (success/failed)
   - Count of specs produced vs failed
   - Highlight categories that cross-reference each other (e.g., security findings that overlap with architecture)
   - Suggest which specs to address first based on severity and impact

8. **Merge opportunity**: After presenting results, ask: "Found <N> specs. Would you like to merge related specs?" Options:
   - `Yes, merge all` — combine all specs into a single file by reading each one, grouping findings by category, deduplicating overlapping items, and writing to `plans/merged-audit-<date>.md`. Then remove the individual spec files.
   - `Yes, but let me pick which` — present the list and let the user select which to merge. Combine the selected ones into one file, remove them, and keep the unselected ones separate.
   - `No, keep them separate` — continue

9. **Open questions**: For each spec, present a summary of its open questions and ask the user if they want to resolve them now (batch where possible) or skip. Include a "Skip remaining" option.

10. **Post-clarification implementation offer**: After the open questions step, ask: "Would you like to implement these specs now?"
    - **Yes, implement all** — run `/implement` for each spec file produced
    - **Yes, implement specific specs** — let the user pick which ones
    - **No, just keep the plans** — end the command

## Category Selection Heuristics

When the user does not specify categories explicitly, use these heuristics to suggest the most relevant subset:

- **Comprehensive audit**: `--all` — everything from security to test coverage
- **Quality-focused**: `quality`, `review`, `test`, `security`, `optimize`
- **Architecture review**: `architecture`, `devtools`, `reuse`, `migration`, `deploy`
- **Feature planning**: `design`, `innovate`, `engage`, `fix`, `tutorial`
- **CI/CD & Process**: `ci`, `deploy`, `comments`, `jira`
- **Config & Meta**: `agents-md`, `opencode`, `devtools`

Suggest the most relevant set based on the user's scope/description. Present it as a suggestion and let the user confirm or modify.

## Todoist URL Preservation

If `$ARGUMENTS` contains a Todoist URL (`app.todoist.com/...`):
1. Extract the URL(s) from the arguments
2. Pass them to each agent so they can add YAML frontmatter with the `todoist` field to their spec files
3. If no Todoist URL is present, agents omit frontmatter entirely

Do NOT implement anything or apply changes — this command produces planning documents only.
