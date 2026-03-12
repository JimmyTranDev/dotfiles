---
name: improve
description: Improve user-facing behavior, UX, reliability, and overall product quality
---

Usage: /improve [scope or focus area]

Analyze the specified code from the user's perspective and apply improvements that make the product better for its users.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus on those
   - If the user describes an area or concern, search the codebase to locate the relevant code
   - If no scope is given, analyze recent changes via `git diff` and `git log --oneline -20` against the base branch (prefer `develop`, fall back to `main`)
   - Run tests or build commands if available to establish a working baseline before making changes

2. Load the **convention-matcher**, **simplifier**, and **deduplicator** skills in parallel, then scan for user-focused improvement opportunities across these categories:
   - **User experience**: confusing workflows, missing feedback, unclear error messages, inconsistent behavior, slow interactions
   - **Reliability**: unhandled edge cases, silent failures, missing validation, data loss scenarios, race conditions users could trigger
   - **Performance users feel**: slow page loads, unresponsive UI, laggy interactions, unnecessary loading states, expensive operations blocking the main thread
   - **Error recovery**: unhelpful error messages, missing retry mechanisms, dead-end states users can't escape, unclear next steps after failures
   - **Accessibility**: missing labels, keyboard navigation gaps, screen reader issues, contrast problems, focus management
   - **Input handling**: missing validation, lack of helpful defaults, poor autofill support, unclear required vs optional fields, no confirmation for destructive actions
   - **Data integrity**: missing null checks that could surface as user-visible bugs, unsafe assumptions about data shape, stale state shown to users

3. Prioritize the findings:
   - Rank improvements by user impact (high, medium, low) — how much the issue affects real users in frequency and severity
   - For each improvement, explain what the user experiences today, why it's a problem, and how the fix improves their experience

4. Apply the improvements:
   - Make changes incrementally, verifying each improvement doesn't break existing behavior
   - Preserve existing conventions and patterns — improve within the established style, not against it
   - Prefer changes that users will directly notice over internal-only cleanups (use `/refactor` for code quality)

5. Load additional skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Skills to load (load all applicable in a single parallel batch):
   - **accessibility**: Load if UI components are in scope
   - **logic-checker**: Load if improvements touch user-facing workflows or state management

   Agents to delegate to (launch independent agents in parallel):
   - **optimizer** + **tester**: Launch in parallel — optimizer handles user-perceptible performance improvements while tester runs existing tests and adds coverage for improved code
   - **reviewer** + **auditor**: Launch in parallel after improvements are applied — reviewer verifies correctness while auditor scans security-sensitive changes

6. After improving:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize each improvement applied: what the user experience was before, what it is now, and why it's better
   - List any additional user-facing improvement opportunities that were out of scope but worth noting for future work
