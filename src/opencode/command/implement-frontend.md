---
name: implement-frontend
description: Full frontend pipeline — clarify, plan, implement, then multi-agent review with designer, reviewer, optimizer, and refactorer
---

Usage: /implement-frontend [feature description, file path, or plans/*.md spec]

$ARGUMENTS

A four-stage pipeline for building frontend features in the current working directory: **clarify → plan → implement → multi-agent review (auto-fix)**. All work happens in-place on the current branch — no worktree, no PR. If no arguments are provided, ask the user what frontend work they want to build.

## Stage 0: Stack Detection and Skill Loading

Run `detect-stack.sh` to identify the framework (React web, React Native/Expo, etc.), package manager, CSS approach, and test runner.

Load applicable skills in a SINGLE parallel batch (never one at a time):
- **meta-parallelization**: Always — maximize parallel execution across every stage
- **code-follower**: Always — match existing component patterns, naming, file structure, and styling
- **react-typescript**: Load for React/React Native projects — component, hook, state, and data-fetching conventions
- **ui-designer**: Always — component architecture, layout, theming, design tokens, responsive design
- **ui-accessibility**: Always — WCAG, ARIA, keyboard navigation, screen reader, mobile a11y props
- **review-frontend**: Always — XSS, bundle size, render performance, state anti-patterns (drives the review stage)
- **ts-total-typescript**: Load when the work involves non-trivial TypeScript types, generics, or inference
- **ui-animator**: Load when the scope involves transitions, animations, micro-interactions, or loading states
- **tool-tailwind**: Load when the project uses Tailwind/NativeWind
- **tool-react-query**: Load when the feature fetches or mutates server state
- **tool-zustand**: Load when the feature touches global client state
- **performance-patterns**: Load when the feature involves large lists, heavy renders, or perceived-performance concerns

## Stage 1: Clarify (interactive)

Run the clarification pass before any code is written — this stage is interactive and always runs unless `$ARGUMENTS` references a `plans/*.md` spec (those are already clarified, so skip to Stage 2).

1. Load the **code-logic-checker** and **comm-spec-writer** skills in parallel.
2. Parse the input. If it references a file, issue, or PR, read it for full context.
3. Explore the codebase in parallel for existing components, design tokens, routing, and state patterns that inform the questions.
4. Identify ambiguity across: scope, behavior, edge cases (empty/loading/error states), responsive/breakpoint requirements, accessibility expectations, data dependencies, and acceptance criteria.
5. Use the question tool to ask 5-10 targeted questions, each with concrete options where possible. Skip anything already answered by the input or discoverable from the codebase.
6. Summarize the clarified requirements as a concise spec before continuing.

Do not proceed to planning until critical ambiguities are resolved.

## Stage 2: Plan

Launch the **planner** agent on the clarified requirements to decompose the work into an ordered task list with dependencies and complexity estimates.

- Create a TodoWrite todo for each planned task (all `pending`).
- Present the plan to the user. Use the question tool: "Proceed with this plan?" Options: "Yes, implement" / "Adjust the plan". If adjusting, revise and re-present.

## Stage 3: Implement

Work through the plan, marking each todo `in_progress` then `completed`. Maximize parallelism per the **meta-parallelization** skill.

- Delegate UI component work (screens, components, styling, accessibility, responsive behavior) to the **designer** agent.
- Delegate non-UI frontend logic (hooks, state stores, data fetching, routing, utilities) to the **implementer** agent.
- Launch independent agents in parallel when their tasks touch different files; serialize only when one depends on another's output.
- Batch related file reads and searches into parallel calls.

After implementation, run verification checks in a single parallel batch: `build-check.sh`, `type-check.sh`, `lint-check.sh`, `format-check.sh`. Fix any failures before the review stage.

## Stage 4: Multi-Agent Review (auto-fix then re-verify)

Launch all four review agents **in parallel** on the implemented diff (`git diff HEAD`):

| Agent | Focus |
|-------|-------|
| **designer** | Visual states, accessibility, responsive behavior, component structure, design-token usage |
| **reviewer** | Correctness, bugs, design issues, maintainability |
| **optimizer** | Re-renders, memoization, bundle size, list virtualization, perceived performance |
| **refactorer** | Duplication, over-separation, misplaced responsibility, naming, structural cleanup |

Then run the auto-fix cycle:

1. Collect findings from all four agents and de-duplicate overlapping items.
2. Launch **fixer** agents in parallel for independent fixes across different files. Refactor-only findings go to the **refactorer** agent.
3. Re-run the verification batch (`build-check.sh`, `type-check.sh`, `lint-check.sh`, `format-check.sh`).
4. Re-run **reviewer** to confirm the findings are resolved. Repeat the fix cycle a maximum of 2 iterations; if issues remain after 2 iterations, list them for the user.

## Stage 5: Finalize

1. Stage and commit the changes using the commit format from the **git-workflows** skill: `git add -A && git commit -m "<type>(<scope>): <description>"`. Do not push unless the user explicitly asks.
2. **Spec cleanup + Todoist completion**: Follow the Spec Cleanup and Todoist Completion convention in AGENTS.md.
3. Report a summary: tasks completed, files changed, review findings fixed per agent, and any unresolved items.

## Constraints

- All work happens in the current working directory on the current branch — no worktree, no PR.
- Frontend only — if the feature requires backend/API changes, flag them and ask the user how to proceed rather than implementing them here.
- Keep components presentational; isolate business logic, data fetching, and state into hooks/stores.
- Never introduce new styling libraries, icon sets, or design systems — match what the project already uses.
- If a planned task fails, mark its todo `pending`, notify the user, and ask whether to continue with remaining tasks or stop.
