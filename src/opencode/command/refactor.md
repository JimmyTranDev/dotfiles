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

3. Load all applicable skills in parallel (**convention-matcher**, **simplifier**, **deduplicator**, and optionally **import-optimizer** and **logic-checker**), then analyze the code for refactoring opportunities (duplication, complexity, dead code, over-engineering, naming, structure) and apply DRY, KISS, YAGNI principles while preserving existing behavior

4. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **optimizer**: Use if performance-sensitive code is identified during refactoring
   - **reviewer** + **tester**: Launch in parallel after refactoring is complete — reviewer verifies correctness while tester runs tests and adds coverage

5. After refactoring:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize what was changed and why
   - List any follow-up improvements that were out of scope but worth noting

6. **Commit, rebase, and clean up** the worktree following the Worktree Workflow in AGENTS.md
