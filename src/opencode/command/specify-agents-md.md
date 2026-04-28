---
name: specify-agents-md
description: Analyze repository structure and report AGENTS.md improvements needed without making changes and write spec to `spec/`
---

Usage: /specify-agents-md $ARGUMENTS

Analyze the current repository and identify where AGENTS.md files should be created or updated. If $ARGUMENTS specifies a path or scope, focus on that area. Otherwise, analyze the entire repo. Do NOT apply any changes — write all findings to a spec file.

1. Load the **meta-agents-md** skill to understand AGENTS.md structure, content principles, and what belongs vs. what doesn't

2. **Scan the repo** to understand its structure:
   - Read the repo root to identify major directories, languages, and frameworks
   - Check for existing AGENTS.md files at all levels (root and subdirectories)
   - Identify the tech stack from package.json, Cargo.toml, go.mod, pyproject.toml, or similar

3. **Determine where AGENTS.md files are needed** using this decision tree:

   | Location | Create When |
   |----------|-------------|
   | Repo root `AGENTS.md` | Always — every repo benefits from root-level agent instructions |
   | `src/AGENTS.md` or `app/AGENTS.md` | Main source directory has conventions not obvious from code alone |
   | `<package>/AGENTS.md` | Monorepo packages with distinct tech stacks or conventions |
   | `<subdir>/AGENTS.md` | Directory has unique rules that differ from the repo root (e.g., generated code, different language, special build process) |

   Skip directories that:
   - Are generated or vendored (`node_modules`, `dist`, `build`, `.next`, `vendor`)
   - Already have an AGENTS.md that is complete and accurate
   - Have fewer than 3 source files (not enough complexity to warrant one)

4. **For each location**, analyze the surrounding code to extract:
   - Repository or directory structure with purpose annotations
   - Coding conventions actually used (naming, patterns, architecture)
   - Tech stack and framework-specific patterns
   - Build, test, and lint commands
   - Import conventions and module boundaries
   - Any non-obvious rules an agent would need to know

5. **Draft each proposed AGENTS.md** following these rules:
   - Start with the no-comments policy if the repo follows it
   - Use `##` section headers, bullet lists, and tables — no prose paragraphs
   - Write rules as short imperative directives, not explanations
   - Include a directory structure tree if the layout isn't self-evident
   - Reference existing tooling (linters, formatters, test runners) so agents use them
   - Do not duplicate content that belongs in skills or that a parent AGENTS.md already covers
   - Subdirectory AGENTS.md files should only contain rules specific to that directory

6. **Auto-sync check** — cross-reference existing AGENTS.md content against the actual file system:
   - Verify every file and directory referenced in AGENTS.md actually exists (run `ls` or glob to confirm)
   - Verify every directory tree in AGENTS.md matches the real structure (check for added/removed files)
   - Flag any references to non-existent files, removed commands, deprecated skills, or stale paths
   - Check that any listed skills, commands, or agents still exist in their expected locations

7. **For existing AGENTS.md files**, diff the current content against what the codebase actually does:
   - Flag sections that are outdated (reference removed files, old patterns, wrong structure)
   - Identify missing sections for conventions the file doesn't cover
   - Identify inaccurate information that should be removed or updated

8. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - For each location, include whether it needs a new AGENTS.md or updates to an existing one
   - Show the proposed content or diff for each file
   - Group by priority: critical fixes (stale references, wrong info) > new files needed > minor improvements

9. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Verify proposed AGENTS.md content is accurate and follows conventions

10. Write findings to a spec file:
    - Create the `spec/` directory if it doesn't exist
    - Choose the filename: use the `agents-md-` prefix followed by a descriptive kebab-case name based on the scope or key findings (e.g., `spec/agents-md-src-directory.md`, `spec/agents-md-stale-references.md`)
    - If a file with the chosen name already exists, append a numeric suffix (e.g., `spec/agents-md-src-directory-2.md`)
    - Write all findings to the file: locations needing AGENTS.md files, proposed content for each, stale reference fixes, and priority ranking
    - Print a brief summary to chat: the spec file path, total findings count, and the top 3 highest-priority items

11. After completing the analysis, load the **meta-skill-learnings** skill and improve any relevant skills with reusable patterns, gotchas, or anti-patterns discovered during the analysis.
