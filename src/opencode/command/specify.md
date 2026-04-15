---
name: specify
description: Generate an implementation spec with file-level tasks, data flow, and open questions in plans/
---

Usage: /specify <feature or task description>

Analyze the project and the user's request, then produce an implementation specification in `plans/` at the project root. The spec breaks the work into concrete file-level tasks, maps data flow, identifies dependencies, and collects open questions — everything needed to start building without ambiguity. This command does NOT implement anything or launch agents. It produces planning documents only.

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

4. Write `plans/spec.md` — the core implementation specification:
   - **Overview**: 2-3 sentence summary of what will be built and why
   - **Architecture**: How the feature fits into the existing codebase — which layers it touches, where new code goes, how it connects to existing modules
   - **Data flow**: Step-by-step description of how data moves through the system for this feature — from input to storage to output
   - **File-level tasks**: An ordered list of every file that needs to be created or modified, with:
     - File path
     - What changes are needed (new file, add function, modify existing logic, etc.)
     - Dependencies on other tasks in the list (which tasks must complete first)
     - Estimated complexity (small/medium/large)
   - **API contracts**: If applicable — new endpoints, function signatures, type definitions, or interfaces that other code will depend on. Define these precisely so dependent tasks can proceed in parallel.
   - **State changes**: New database tables, config entries, environment variables, or stored state this feature introduces
   - **Edge cases**: Known edge cases, error conditions, and boundary behaviors that the implementation must handle
   - **Testing approach**: What tests are needed — unit, integration, e2e — and what behaviors they should verify

5. Write `plans/tasks.md` — a flat, ordered task list extracted from the spec:
   - Each task is one atomic unit of work (create a file, modify a function, add a test)
   - Tasks are ordered by dependency — independent tasks grouped together, dependent tasks sequenced
   - Each task includes the file path, a one-line description, and which other tasks it depends on
   - Mark tasks that can be done in parallel vs those that must be sequential

6. Write `plans/questions.md` — open questions and ambiguities that need human input before implementation:
   - **Requirements questions**: Unclear behavior, missing acceptance criteria, ambiguous edge cases
   - **Architecture questions**: Multiple valid approaches where the user's preference matters
   - **Scope questions**: What's in scope vs out of scope, MVP vs full implementation
   - **Convention questions**: Where existing patterns don't clearly apply to the new feature
   - **Risk questions**: Potential breaking changes, performance concerns, or security implications that need acknowledgment

7. Present the summary in chat:
   - List the files written to `plans/`
   - State the total number of tasks and estimated overall complexity
   - Highlight the critical path (longest chain of dependent tasks)
   - Note the number of open questions that need answers before starting
   - Suggest which task to start with

Do NOT implement anything, launch agents, or apply changes — this command produces planning documents only.
