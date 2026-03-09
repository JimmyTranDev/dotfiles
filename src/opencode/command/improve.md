---
name: improve
description: Analyze code for quality, performance, and design improvements and apply them
---

Usage: /improve [scope or focus area]

Analyze the specified code for improvement opportunities and apply the most impactful ones.

$ARGUMENTS

1. **Create a worktree** following the Worktree Workflow in AGENTS.md — name the branch after the improvement scope

2. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or concern, search the codebase to locate the relevant code
   - If no scope is given, analyze recent changes via `git diff` and `git log --oneline -20` against the base branch (prefer `develop`, fall back to `main`)
   - Run tests or build commands if available to establish a working baseline before making changes

3. Load the **convention-matcher**, **simplifier**, and **deduplicator** skills in parallel, then scan for improvement opportunities across these categories:
   - **Code quality**: naming clarity, function length, complexity, readability
   - **Architecture**: separation of concerns, coupling, cohesion, abstraction levels
   - **Duplication**: repeated patterns, copy-pasted logic, similar implementations that could be unified
   - **Performance**: unnecessary re-renders, expensive operations, missing memoization, inefficient algorithms
   - **Error handling**: missing error cases, silent failures, inconsistent error patterns
   - **Type safety**: loose types, missing null checks, `any` usage, unsafe casts
   - **Dead code**: unused exports, unreachable branches, deprecated patterns still in place

4. Prioritize the findings:
   - Rank improvements by impact (high, medium, low) considering both code quality gain and risk of change
   - For each improvement, explain what is wrong, why it matters, and what the fix looks like

5. Apply the improvements:
   - Make changes incrementally, verifying each improvement doesn't break existing behavior
   - Preserve existing conventions and patterns — improve within the established style, not against it

6. Load additional skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Skills to load (load all applicable in a single parallel batch):
   - **import-optimizer**: Load if barrel files, circular dependencies, or re-export chains are found
   - **logic-checker**: Load if improvements touch complex conditionals or state management

   Agents to delegate to (launch independent agents in parallel):
   - **optimizer** + **tester**: Launch in parallel — optimizer handles performance improvements while tester runs existing tests and adds coverage for improved code
   - **reviewer** + **auditor**: Launch in parallel after improvements are applied — reviewer verifies correctness while auditor scans security-sensitive changes

7. After improving:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize each improvement applied: what changed, why it's better, and any measurable impact
   - List any additional improvement opportunities that were out of scope but worth noting for future work

8. **Commit, merge, and clean up** the worktree following the Worktree Workflow in AGENTS.md
