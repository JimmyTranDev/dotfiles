---
name: improve-agents-md
---

Usage: /improve-agents-md $ARGUMENTS

Analyze the current repository and create or update AGENTS.md files where they would provide value to AI agents. If $ARGUMENTS specifies a path or scope, focus on that area. Otherwise, analyze the entire repo.

1. Load the **agents-md** skill to understand AGENTS.md structure, content principles, and what belongs vs. what doesn't

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

5. **Draft each AGENTS.md** following these rules:
   - Start with the no-comments policy if the repo follows it
   - Use `##` section headers, bullet lists, and tables — no prose paragraphs
   - Write rules as short imperative directives, not explanations
   - Include a directory structure tree if the layout isn't self-evident
   - Reference existing tooling (linters, formatters, test runners) so agents use them
   - Do not duplicate content that belongs in skills or that a parent AGENTS.md already covers
   - Subdirectory AGENTS.md files should only contain rules specific to that directory

6. **Auto-sync check** — cross-reference AGENTS.md content against the actual file system:
   - Verify every file and directory referenced in AGENTS.md actually exists (run `ls` or glob to confirm)
   - Verify every directory tree in AGENTS.md matches the real structure (check for added/removed files)
   - Flag any references to non-existent files, removed commands, deprecated skills, or stale paths
   - Check that any listed skills, commands, or agents still exist in their expected locations

7. **For existing AGENTS.md files**, diff the current content against what the codebase actually does:
   - Flag sections that are outdated (reference removed files, old patterns, wrong structure)
   - Add missing sections for conventions the file doesn't cover
   - Remove or update inaccurate information
   - Preserve the existing section ordering where possible

8. **Present changes to the user** before writing:
   - For new files: show the proposed content and location
   - For updates: show what will change and why
   - Ask for confirmation before writing

Important:
- Never add domain knowledge that belongs in a skill — AGENTS.md is for behavioral rules and repo context only
- Keep each AGENTS.md under 100 lines — concise directives are more effective than lengthy guides
- Subdirectory AGENTS.md files should be much shorter than root — only directory-specific rules
- Do not include secrets, credentials, or sensitive paths
- Match the tone and style of any existing AGENTS.md files in the repo
