---
name: convention
description: Enforce coding conventions from the conventions skill on specified code
---

Usage: /convention [scope or description]

Analyze the specified code and refactor it to strictly follow every convention defined in the **conventions** skill.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or pattern, search the codebase to locate the relevant code
   - If no scope is given, analyze recently modified files via `git diff --name-only HEAD~5`

2. Load the **conventions** and **follower** skills in parallel, then audit every file in scope against all convention rules:
   - **General**: early returns over nested `else if`, no swallowed errors, meaningful error messages
   - **TypeScript Code Rules**: strict null handling, `const` over `let`, no `var`, arrow functions for callbacks, template literals over concatenation
   - **Module Structure**: components/hooks in folders with `index.tsx` entry point, supporting files (`utils.ts`, `hooks.ts`, `consts.ts`, `types.ts`) alongside
   - **Error Handling**: throw for exceptional cases, result types for expected failures, async errors caught with try/catch or `.catch()`
   - **Imports**: external packages first, grouped by source, direct imports over barrel re-exports
   - **Project Setup**: pnpm for projects, bun for scripts/tooling, Vite bundler, ESLint + Prettier or Biome, Vitest

3. For each violation found, report:
   - The file and line
   - Which convention is violated
   - What the code currently does vs. what the convention requires

4. Apply all fixes:
   - Refactor each violation to conform to the convention
   - Preserve existing behavior — convention enforcement is structural, not functional
   - Follow the existing codebase style as determined by the **follower** skill

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel after fixes):
   - **reviewer**: Verify refactored code is correct and no behavior changed
   - **tester**: Run tests to confirm nothing broke

6. After enforcement:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize each violation fixed: what the issue was, which convention it violated, and the change made
   - List any violations that could not be auto-fixed and require manual attention

Important:
- Never change user-facing behavior — convention enforcement is purely structural
- Never introduce new patterns that contradict existing codebase conventions
- If a convention conflicts with an established project pattern, flag it for the user instead of forcing the change
- Do not reorganize file structure unless the module structure convention is clearly violated
