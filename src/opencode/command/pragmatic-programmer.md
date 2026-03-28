---
name: pragmatic-programmer
description: Apply Pragmatic Programmer principles to improve code quality, design, and robustness
---

Usage: /pragmatic-programmer [scope or description]

Analyze the specified code through the lens of Pragmatic Programmer principles and apply improvements.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or pattern, search the codebase to locate the relevant code
   - If no scope is given, analyze recently changed files via `git diff --name-only HEAD~5`
   - Run tests or build commands if available to establish a working baseline before making changes

2. Load skills and analyze — load **pragmatic-programmer** and **follower** skills in parallel, then audit the code for violations across these categories:
   - **DRY violations**: Duplicated knowledge, copy-pasted logic, parallel structures that must stay in sync
   - **Orthogonality issues**: Coupled modules, changes that ripple across unrelated code, shared mutable state
   - **Broken windows**: Accumulated TODOs, inconsistent patterns, known issues left to rot
   - **Pragmatic paranoia**: Missing input validation, silent failures, ambiguous return values, catch-all error handlers
   - **Reversibility concerns**: Hardcoded vendor dependencies, framework types leaking into domain logic, irreversible design decisions
   - **Naming and readability**: Names that require comments to understand, abbreviations, misleading identifiers
   - **Anti-patterns**: Programming by coincidence, cargo cult code, primitive obsession, temporal coupling, feature envy, speculative generality, dead code

3. Prioritize the findings:
   - Rank issues by impact (high, medium, low) considering correctness risk, maintenance burden, and decay potential
   - For each issue, identify which Pragmatic Programmer principle is violated and what the fix looks like

4. Apply the improvements:
   - Make changes incrementally, verifying each change preserves existing behavior
   - Preserve existing conventions — improve within the established style
   - Focus on the highest-impact issues first

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **fixer**: Use for specific bugs uncovered during analysis
   - **reviewer** + **tester**: Launch in parallel after improvements are complete — reviewer verifies correctness while tester runs tests and adds coverage

6. After improvements:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize each improvement: which principle was violated, what changed, and how it improves the codebase
   - List any follow-up opportunities that were out of scope

7. Add follow-up items to `IMPROVEMENTS.md` at the project root:
   - If `IMPROVEMENTS.md` does not exist, create it with a `# IMPROVEMENTS` heading
   - If it exists, read its current contents and avoid adding duplicates (case-insensitive match)
   - Append each follow-up opportunity as `- [ ] <description> [pragmatic-programmer]`
   - Preserve all existing content and formatting
   - Report how many items were added and how many were skipped as duplicates
