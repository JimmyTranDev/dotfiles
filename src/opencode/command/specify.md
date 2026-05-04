---
name: specify
description: Generate implementation specs in plans/ — one file per task group, scaled to complexity
---

Usage: /specify [category] [scope or description]

Analyze the project and the user's request, then produce implementation specification files in `plans/` at the project root. For small features, write a single spec. For larger features with many tasks, split into multiple focused spec files — one per logical task group. Each spec contains everything needed to start building its piece without ambiguity. This command does NOT implement anything or launch agents. It produces planning documents only.

$ARGUMENTS

1. Determine the category from `$ARGUMENTS`:
   - If the first word is an exact category name, use it
   - If the first word is a synonym, abbreviation, or close match, map it to the correct category:
     - `sec`, `vuln`, `vulnerabilities` → `security`
     - `perf`, `performance`, `speed` → `optimize`
     - `tests`, `coverage`, `testing` → `test`
     - `bugs`, `correctness`, `logic` → `review`
     - `code-quality`, `smells`, `refactor` → `quality`
     - `deps`, `dependencies`, `audit` → `security` (or `devtools` based on context)
     - `ui`, `ux`, `accessibility`, `a11y` → `design`
     - `dx`, `tooling`, `linting` → `devtools`
     - `duplication`, `dry`, `dedup` → `reuse`
     - `structure`, `modules`, `coupling` → `architecture`
     - `ideas`, `features`, `brainstorm` → `innovate`
     - `engagement`, `retention`, `habits` → `engage`
     - `agents`, `agents.md` → `agents-md`
     - `bug`, `error`, `crash`, `broken` → `fix`
     - `pr`, `pr-comments`, `feedback` → `comments`
     - `github-actions`, `pipeline`, `workflow` → `ci`
     - `steps`, `walkthrough`, `how-to` → `tutorial`
     - `ticket`, `jira` → `jira`
   - If no category can be determined, present the list of categories using the question tool and ask the user to pick one
   - The remaining text after the category becomes the scope/description

2. Load the **specify-{category}** skill. This skill defines:
   - Spec filename prefix
   - Skills to load
   - Agents to launch
   - Analysis categories and checklists
   - Severity classification
   - Any scope overrides or unique workflow steps

3. Create the `plans/` directory at the project root if it doesn't exist.

4. Decide how many spec files to produce:
   - If the feature has ~10 or fewer tasks that form a single cohesive unit, write one spec file
   - If the feature has many tasks that naturally group into distinct areas (e.g., database layer, API endpoints, UI components, auth integration), split into one spec file per group
   - Each spec file should be independently actionable — a developer can pick up one file and implement its tasks without reading the others first (though cross-references are fine)

5. Choose descriptive filenames:
   - Derive from the task/group description using kebab-case
   - For a single spec: e.g., `plans/csv-export-api.md`
   - For multiple specs: use a shared prefix, e.g., `plans/checkout-db-schema.md`, `plans/checkout-api.md`, `plans/checkout-ui.md`
   - Keep names short (2-4 words) but specific enough to identify the scope at a glance
   - Check `plans/` for existing files and avoid name collisions

6. Write each spec file with these sections:
   - **Overview**: 2-3 sentence summary of what this spec covers and why
   - **Architecture**: How this piece fits into the existing codebase — which layers it touches, where new code goes, how it connects to existing modules
   - **Data flow**: Step-by-step description of how data moves through the system for this piece — from input to storage to output
   - **Tasks**: An ordered list of every file that needs to be created or modified, with:
     - File path
     - What changes are needed (new file, add function, modify existing logic, etc.)
     - Dependencies on other tasks (within this spec or cross-referencing another spec file)
     - Estimated complexity (small/medium/large)
     - Whether the task can run in parallel with others or must be sequential
   - **API contracts**: If applicable — new endpoints, function signatures, type definitions, or interfaces that other code will depend on. Define these precisely so dependent tasks can proceed in parallel.
   - **State changes**: New database tables, config entries, environment variables, or stored state this piece introduces
   - **Edge cases**: Known edge cases, error conditions, and boundary behaviors that the implementation must handle
   - **Testing approach**: What tests are needed — unit, integration, e2e — and what behaviors they should verify
   - **Open questions**: Ambiguities that need human input before implementation, grouped by:
     - Requirements — unclear behavior, missing acceptance criteria, ambiguous edge cases
     - Architecture — multiple valid approaches where the user's preference matters
     - Scope — what's in scope vs out of scope, MVP vs full implementation
     - Conventions — where existing patterns don't clearly apply to the new feature
     - Risks — potential breaking changes, performance concerns, or security implications

7. Present the summary in chat:
   - List all spec files written (e.g., `plans/checkout-db-schema.md`, `plans/checkout-api.md`)
   - State the total number of tasks across all specs and estimated overall complexity
   - Highlight the critical path (longest chain of dependent tasks, including cross-spec dependencies)
   - Note the number of open questions that need answers before starting
   - Show which specs can be worked on in parallel vs which have ordering constraints
   - Suggest which spec to start with

Do NOT implement anything, launch agents, or apply changes — this command produces planning documents only.

## Post-Specification Clarification

After writing all spec files and presenting the summary, automatically iterate through all open questions across all specs:

1. Collect all questions from the "Open questions" sections of the generated spec files
2. For each question, present it to the user using the question tool with concrete options where possible
3. Include a "Skip remaining" option in every question to let the user stop early
4. After each answer, update the spec file inline — replace the open question with a "Decision: [answer]" statement
5. If the user's answer invalidates an earlier task or architectural decision in the spec, update that section too
6. After all questions are answered (or skipped), note how many decisions were recorded
