---
name: specify-simplify
description: Analyze code for simplification opportunities and report refactoring suggestions without making changes and write spec to `spec/simplify/`
---

Usage: /specify-simplify [scope or description]

Analyze the target code for simplification opportunities — code smells, unnecessary complexity, and refactoring candidates — and report suggestions without applying any changes. Write all findings to a spec file.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes a pattern or area, search the codebase to locate the relevant code
   - If no scope is given, ask the user what code they want analyzed

2. Load all applicable skills in parallel (**code-simplifier**, **code-follower**, **code-conventions**, **code-deduplicator**), then analyze the code for simplification opportunities:
   - Read all target files and their direct dependents (callers, importers)
   - Identify code smells: deep nesting, long functions, redundant abstractions, overly clever logic, duplicated patterns, dead branches, unnecessary indirection
   - Map the public API surface — what do consumers actually use?

3. For each simplification opportunity, document:
   - The code smell and its location (file path, line number)
   - Why it adds unnecessary complexity
   - A concrete suggestion showing what the simplified code would look like
   - Estimated impact on readability and maintainability

4. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - Group findings by category:
     - **Extract**: repeated logic that should be shared utilities
     - **Flatten**: deeply nested conditionals that could use early returns
     - **Inline**: trivial single-use abstractions that add indirection
     - **Remove**: dead code, unused parameters, unreachable branches
     - **Replace**: imperative loops replaceable with declarative transforms
     - **Simplify**: state management with unnecessary intermediaries
     - **Rename**: misleading names that obscure intent
   - Within each category, rank by impact (high first)

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **reviewer**: Verify simplification suggestions preserve behavior and follow conventions

6. Write findings to a spec file:
   - Create the `spec/simplify/` directory if it doesn't exist
   - Choose the filename: if the user provided a scope description, convert it to kebab-case and use it as the filename (e.g., `auth-module.md`); otherwise use a timestamp (`YYYY-MM-DDTHH-MM-SS.md`)
   - If a file with the chosen name already exists, append a timestamp suffix before the extension
   - Write all findings to the file: grouped by category, ranked by impact, with file location, code smell description, suggested simplification, and estimated impact for each item
   - Print a brief summary to chat: the spec file path, total findings count, and the top 3 highest-impact items
