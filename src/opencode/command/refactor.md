---
name: refactor
description: Refactor and simplify code by applying DRY, KISS, and YAGNI principles
---

Usage: /refactor [scope or description]

Refactor the specified code for simplicity, clarity, and maintainability.

$ARGUMENTS

1. **Create a worktree** following the Worktree Workflow in AGENTS.md — name the branch after the refactoring scope

2. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or pattern, search the codebase to locate the relevant code
   - Run tests or build commands if available to establish a working baseline before making changes

3. Load the **simplifier** and **deduplicator** skills, then analyze the code for refactoring opportunities (duplication, complexity, dead code, over-engineering, naming, structure) and apply DRY, KISS, YAGNI principles while preserving existing behavior

4. Load relevant skills and delegate to specialized agents in parallel where applicable:

   Skills to load:
   - **convention-matcher**: Always load first to learn codebase conventions so refactored code matches the existing style
   - **import-optimizer**: Load if barrel files, circular dependencies, or re-export chains are found
   - **logic-checker**: Load if refactored logic involves complex conditionals or state to verify correctness

   Agents to delegate to:
   - **optimizer**: Use if performance-sensitive code is identified during refactoring
   - **reviewer**: Use after refactoring is complete to verify the changes are sound and nothing was broken
   - **tester**: Use to run existing tests or add tests if coverage is missing for refactored code

5. After refactoring:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize what was changed and why
   - List any follow-up improvements that were out of scope but worth noting

6. **Commit, merge, and clean up** the worktree following the Worktree Workflow in AGENTS.md
