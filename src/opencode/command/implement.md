---
name: implement
description: Implement changes based on a description using skills and specialized agents
---

Usage: /implement [description or task list]

$ARGUMENTS

## Mode Detection

Detect sequential mode from `$ARGUMENTS` using any of these signals:
- Explicit flag: `--sequential`
- Natural language: contains phrases like "sequentially", "one by one", "one at a time", "in order", "step by step"
- List format: multiple numbered items (1. ... 2. ...) or bullet points with distinct tasks

If sequential mode is detected:
1. Load the **implement-sequential** and **git-workflows** skills (in parallel with other applicable skills below)
2. Follow the sequential workflow defined in the **implement-sequential** skill
3. Skip the single-task workflow below

If no arguments are provided, ask the user what they want to implement.

Otherwise, proceed with the single-task workflow.

## Single-Task Workflow

1. Parse the prompt to understand what needs to be implemented
2. **Clarify check**: If the request is vague, ambiguous, or could be interpreted in multiple ways, suggest running `/clarify` first. Present the user with an option to proceed anyway or clarify first. Skip this check for unambiguous one-liners or when a `plans/` file is referenced (those are already clarified).
3. Check if the changes described are already present in the codebase
4. If the changes are missing or incomplete, implement them according to the description
5. If the changes are already present, verify they match the description and suggest improvements if needed

After understanding the intent, load relevant skills and delegate to specialized agents — maximize parallelism per the **meta-parallelization** skill and AGENTS.md:

Skills to load — load ALL applicable skills in a SINGLE parallel batch (never one at a time):
- **meta-parallelization**: Always load — maximize parallel execution with fan-out strategies, sizing heuristics, and anti-patterns
- **code-follower**: Always load to study existing codebase conventions (naming, imports, file structure, patterns) so all new code matches the established style
- **code-conventions**: Load when the task describes adding new code to ensure consistent coding patterns
- **code-logic-checker**: Load when the task involves business logic, state machines, or complex conditional flows to verify logical soundness and catch impossible states
- **code-deduplicator**: Load when the task describes extracting shared utilities or reducing duplication across the codebase
- **code-simplifier**: Load when the task describes refactoring or simplification work — apply DRY, KISS, YAGNI principles
- **strategy-pragmatic-programmer**: Load when writing new code or refactoring — apply DRY, orthogonality, tracer bullets, and pragmatic paranoia principles
- **meta-opencode-authoring**: Load when the task describes writing or updating OpenCode agents, commands, or skills
- **ts-total-typescript**: Load when the task involves TypeScript and requires advanced type patterns, generics, branded types, or utility types
- **tool-eslint-config**: Load when the task involves setting up or modifying ESLint configuration
- **meta-shell-scripting**: Load when the task involves writing or modifying shell scripts (bash/zsh)
- **security**: Load when the task touches authentication, authorization, data handling, or external inputs
- **git-gitignore**: Load when the task involves creating or modifying .gitignore files

Agents to delegate to (launch independent agents in parallel — only serialize when one depends on another's output):
- **designer**: Use when the task describes UI component work, accessibility improvements, or frontend feature additions
- **fixer**: Use when the task describes a bug fix, a complex problem with unclear root cause, or a multi-layered issue requiring investigation
- **tester**: Use when the user explicitly asks for tests
- **reviewer**: Use after implementation is complete to catch bugs, design issues, and maintainability problems before finalizing
- **optimizer**: Use when the task describes performance improvements — profile and implement measurable optimizations
- **auditor**: Use when the task describes security-related changes, authentication flows, or data handling to scan for vulnerabilities

### Parallel Agent Combos

| Parallel Batch | Agents | When |
|---------------|--------|------|
| Implementation | **implementer** + **designer** | Feature needs UI |
| Post-Implementation | **reviewer** + **auditor** | Review + audit together |
| Fix | **fixer** × N (one per file/issue) | Multiple independent fixes across different files |
| Post-Fix Verification | **reviewer** (verify) | Sequential — depends on all fixers completing |

### Workflow

1. **Analyze**: Categorize the type of work (feature, fix, refactor, test, security, performance, etc.)
2. **Explore & Load** (parallel):
   - Launch **explore** agent for open-ended codebase searches
   - Run `detect-stack.sh` to identify tech stack
   - Load all applicable skills in a SINGLE parallel batch (always include **code-follower**)
3. **Implement** (parallel):
   - Delegate to the appropriate specialized agents based on work type — launch independent agents in one message
   - Batch related file reads and searches into parallel calls
4. **Verify** (parallel):
   - Run `build-check.sh`, `lint-check.sh`, `type-check.sh`, and `format-check.sh` in a single parallel batch
   - Launch **reviewer** and **auditor** agents together in one message
5. **Fix** (serial — depends on reviewer/auditor output):
   - If issues are found, launch **fixer** agents in parallel for independent fixes across different files
   - Run **reviewer** once more to verify fixes (max 2 iterations)
6. **Spec cleanup + Todoist completion**: Follow the Spec Cleanup and Todoist Completion convention in AGENTS.md.
7. **Post-implementation review offer**: After successful implementation, use the question tool to ask: "Would you like to review the changes?" Options: "Yes, run /review" / "No, skip review". If yes, run `/review` in local mode to review the changes just made. If implementation failed at any step, skip this prompt.
