---
name: opencode
description: Analyze the current project, suggest agents/commands/skills, and create or update AGENTS.md with project conventions
---

Usage: /generate-config [focus area or constraints]

Analyze the current project's tech stack, architecture, and workflows to suggest high-value OpenCode agents, commands, and skills tailored to this specific codebase. Write suggestions to a `plans/` file, then create or update the project's AGENTS.md with discovered conventions.

$ARGUMENTS

1. Detect the project's tech stack (run in parallel):
   - Read `package.json`, `pom.xml`, `build.gradle`, `Cargo.toml`, `go.mod`, `requirements.txt`, `Gemfile`, or similar manifest files
   - List top-level directories to understand project structure
   - Read any existing `.opencode/` config (agents, commands, skills) to avoid duplicates
   - Read `README.md` or similar for project context
   - Check CI config (`.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml`) for build/deploy patterns
   - Run `git log --oneline -20` to understand recent development activity

2. Load skills: **meta-opencode-authoring**, **code-follower**. Analyze the project across these dimensions:

   **Skills to suggest** — domain knowledge the AI would need repeatedly:
   - Frameworks and libraries used (e.g., a Next.js project benefits from `tool-nextjs`)
   - Database/ORM patterns (Drizzle, Prisma, TypeORM, Hibernate)
   - Testing frameworks (Vitest, Jest, JUnit, pytest)
   - Infrastructure tools (Docker, Terraform, K8s)
   - API patterns (REST conventions, GraphQL schema patterns)
   - Project-specific conventions not covered by global skills

   **Commands to suggest** — repetitive workflows developers run often:
   - Build/test/lint shortcuts with project-specific flags
   - Deployment workflows for the project's infra
   - Code generation patterns (migrations, components, routes)
   - Review workflows tailored to the project's architecture
   - Data seeding or environment setup

   **Agents to suggest** — specialized roles for this project's domain:
   - Domain-specific reviewers (e.g., "api-reviewer" for an API-heavy project)
   - Migration specialists for the project's ORM
   - Component builders for the project's UI framework
   - Domain experts for business logic areas

3. For each suggestion, provide:
   - Name (kebab-case, following existing naming taxonomy)
   - Type (skill, command, or agent)
   - Description (following meta-opencode-authoring conventions)
   - Rationale (why this project specifically benefits from it)
   - Priority (high/medium/low based on estimated daily usage)
   - Whether it should be project-local (`.opencode/`) or global (`~/.config/opencode/`)

4. Filter suggestions:
   - Exclude anything already covered by global skills/commands/agents in `~/.config/opencode/`
   - Exclude anything too generic (already handled by existing global config)
   - Prioritize project-specific knowledge that the AI struggles with without a skill
   - Limit to 5-10 high-value suggestions (not an exhaustive list)

5. Write output to `plans/generate-config-suggestions.md` with sections:
   - **Project Analysis**: 3-5 sentences summarizing the tech stack and architecture
   - **Existing Config**: What `.opencode/` already has (if anything)
   - **Suggested Skills**: Table with name, description, rationale, priority, scope (local/global)
   - **Suggested Commands**: Table with name, description, rationale, priority
   - **Suggested Agents**: Table with name, description, rationale, priority
   - **Implementation Order**: Which to create first based on daily impact

6. Print summary to chat:
   - Total suggestions count by type
   - Top 3 highest-impact items
   - The plans/ file path for full details

7. Create or update the project's AGENTS.md file. Load skill: **meta-agents-md**.

   **If no AGENTS.md exists** (check `AGENTS.md`, `.opencode/AGENTS.md`, and `.cursorrules` / `.github/copilot-instructions.md`):
   - Create `AGENTS.md` at the project root with these sections:
     - **Project Overview**: 2-3 sentences describing what this project is and its primary tech stack
     - **Tech Stack**: Table listing frameworks, languages, databases, and tools with versions from manifest files
     - **Project Structure**: Key directories and their purpose (src/, tests/, config/, etc.)
     - **Conventions**: Discovered patterns from codebase analysis:
       - Naming conventions (file naming, variable naming, component naming)
       - Import ordering and module structure
       - Error handling patterns
       - Testing patterns (test file location, naming, mocking approach)
       - API patterns (route structure, response format, validation approach)
     - **Commands**: Common development commands (build, test, lint, dev server, deploy)
     - **Domain Context**: Business domain terms and their meanings if discoverable from code

   **If AGENTS.md already exists**:
   - Read the existing file
   - Identify gaps by comparing current codebase state against documented conventions
   - Add missing sections or update outdated information
   - Preserve all existing content that is still accurate
   - Add a `## Recent Changes` section if the file hasn't been updated recently (compare git log activity to file's last modification)

   **Discovery process for conventions**:
   - Scan 5-10 representative source files to detect consistent patterns
   - Check linter configs (`.eslintrc`, `biome.json`, `.prettierrc`) for enforced rules
   - Check `tsconfig.json` / `jsconfig.json` for path aliases and compiler options
   - Check test files for testing patterns (describe/it structure, setup/teardown, mocking)
   - Check git hooks (`.husky/`, `.git/hooks/`) for enforced workflows
   - Only document patterns that appear consistently (3+ occurrences), not one-offs
