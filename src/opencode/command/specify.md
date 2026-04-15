---
name: specify
description: Generate a single implementation spec with tasks, data flow, and open questions in plans/
---

Usage: /specify <feature or task description>

Analyze the project and the user's request, then produce a single implementation specification file in `plans/` at the project root. The spec breaks the work into concrete file-level tasks, maps data flow, identifies dependencies, and collects open questions — everything needed to start building without ambiguity. This command does NOT implement anything or launch agents. It produces a planning document only.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand the tech stack and architecture
   - Run `git log --oneline -30` to understand recent development direction
   - Read key config files, READMEs, or AGENTS.md to understand conventions, patterns, and constraints
   - Identify the testing strategy, build system, and deployment approach

2. Analyze the user's request (`$ARGUMENTS`) and break it down:
   - What is the user asking to build or change?
   - What existing code does this touch?
   - What new code needs to be created?
   - What are the inputs, outputs, and side effects?

3. Create the `plans/` directory at the project root if it doesn't exist.

4. Choose a descriptive filename for the spec:
   - Derive it from the task description using kebab-case (e.g., `plans/user-auth-flow.md`, `plans/csv-export-api.md`, `plans/migrate-to-drizzle.md`)
   - Keep it short (2-4 words) but specific enough to identify the feature at a glance
   - Check `plans/` for existing files and avoid name collisions — if a conflict exists, add a distinguishing suffix

5. Write the single spec file with all sections combined:
   - **Overview**: 2-3 sentence summary of what will be built and why
   - **Architecture**: How the feature fits into the existing codebase — which layers it touches, where new code goes, how it connects to existing modules
   - **Data flow**: Step-by-step description of how data moves through the system for this feature — from input to storage to output
   - **Tasks**: An ordered list of every file that needs to be created or modified, with:
     - File path
     - What changes are needed (new file, add function, modify existing logic, etc.)
     - Dependencies on other tasks in the list (which tasks must complete first)
     - Estimated complexity (small/medium/large)
     - Whether the task can run in parallel with others or must be sequential
   - **API contracts**: If applicable — new endpoints, function signatures, type definitions, or interfaces that other code will depend on. Define these precisely so dependent tasks can proceed in parallel.
   - **State changes**: New database tables, config entries, environment variables, or stored state this feature introduces
   - **Edge cases**: Known edge cases, error conditions, and boundary behaviors that the implementation must handle
   - **Testing approach**: What tests are needed — unit, integration, e2e — and what behaviors they should verify
   - **Open questions**: Ambiguities that need human input before implementation, grouped by:
     - Requirements — unclear behavior, missing acceptance criteria, ambiguous edge cases
     - Architecture — multiple valid approaches where the user's preference matters
     - Scope — what's in scope vs out of scope, MVP vs full implementation
     - Conventions — where existing patterns don't clearly apply to the new feature
     - Risks — potential breaking changes, performance concerns, or security implications

6. Present the summary in chat:
   - State the file written (e.g., `plans/user-auth-flow.md`)
   - State the total number of tasks and estimated overall complexity
   - Highlight the critical path (longest chain of dependent tasks)
   - Note the number of open questions that need answers before starting
   - Suggest which task to start with

Do NOT implement anything, launch agents, or apply changes — this command produces a planning document only.
