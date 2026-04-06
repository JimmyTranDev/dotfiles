---
name: plan
description: Comprehensive project analysis covering quality, logic, review, design, engagement, testing, and innovation
---

Usage: /plan [scope or focus area]

Run a comprehensive analysis of the project across all dimensions — code quality, logic correctness, bug review, UI/UX design, user engagement, test coverage, and innovation opportunities. This is the all-in-one command that combines every `/plan-*` command.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand the tech stack and what the project does
   - Run `git log --oneline -30` to understand recent development direction and momentum
   - Read key config files, READMEs, or AGENTS.md to understand the project's purpose, audience, and platform targets
   - If the user specifies a scope or focus area, narrow all analysis to that scope

2. Delegate to specialized agents — launch ALL of the following in parallel to maximize throughput:
   - **reviewer**: Analyze code for bugs, correctness issues, error handling gaps, race conditions, API contract mismatches, and state management problems (covers `/plan-review` and `/plan-logic`)
   - **auditor**: Scan for security vulnerabilities, logic errors that enable bypasses, and exploitable bugs
   - **tester**: Identify test coverage gaps, missing edge cases, untested error paths, and suggest test cases (covers `/plan-test`)
   - **optimizer**: Identify performance bottlenecks and expensive operations

   Each agent should receive the scope context from step 1.

3. While agents run, load all applicable skills in parallel (**follower**, **simplifier**, **deduplicator**, **pragmatic-programmer**, **logic-checker**, **soundness**, **designer-ui-ux**, **accessibility**, **ux-ui-animator**, **engager**, **gamification**, **innovate**, and optionally **consolidator**, **conventions**, **total-typescript**, **eslint-config**, **shell-scripting**), then perform your own analysis across these dimensions:

   **Code Quality** (from `/plan-quality`):
   - Naming clarity, function design, duplication, over-engineering, type safety, dead code, module structure, architecture

   **Logic Correctness** (from `/plan-logic`):
   - Internal consistency, completeness, boundary behavior, boolean logic, data flow, temporal correctness, state transitions

   **UI/UX Design** (from `/plan-design` — skip if project has no UI):
   - Component architecture, layout and spacing, responsive design, visual consistency, accessibility, state and feedback, animation and motion

   **User Engagement** (from `/plan-engage` — skip if project has no user-facing flows):
   - Onboarding friction, habit loop design, friction audit, retention mechanics, persuasion alignment, cognitive bias opportunities

   **Innovation** (from `/plan-innovate`):
   - New features, user experience enhancements, integrations, automation opportunities, quality of life, scaling and future-proofing

4. For each finding across all dimensions:
   - Give it a short, clear name
   - Include the file path and line number where applicable
   - Describe the issue or opportunity in 1-2 sentences
   - Classify severity or impact (critical/high/medium/low)
   - Estimate effort (small, medium, large)
   - Suggest a concrete fix or implementation approach
   - Suggest which `/command` to run to address it (e.g., `/fix`, `/implement`, `/consolidate`, `/security`)

5. Present the combined analysis:
   - Do NOT apply any changes — this command is analysis-only
   - Group findings by dimension (Quality, Logic, Review, Design, Engagement, Testing, Innovation)
   - Within each dimension, group by category and rank by severity/impact
   - Skip dimensions that don't apply to the project (e.g., skip Design for CLI-only tools)

6. Summarize:
   - Report total findings by dimension and severity
   - Highlight the top 5-10 highest-impact items across all dimensions
   - Flag any critical issues that need immediate attention (security vulnerabilities, data corruption risks, WCAG A/AA failures)
   - Provide a prioritized action plan: what to fix first, what to improve next, what to build when ready

7. Output findings directly in chat as the final response. If the user specifies an output destination (file path, format, etc.), write there instead.
   - When writing to a file, append a new section with a timestamp header (create the file if it doesn't exist)
   - Include each item's dimension, category, severity, file location, description, and suggested `/command`
