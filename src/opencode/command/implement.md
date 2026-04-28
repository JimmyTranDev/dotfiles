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
2. Check if the changes described are already present in the codebase
3. If the changes are missing or incomplete, implement them according to the description
4. If the changes are already present, verify they match the description and suggest improvements if needed

After understanding the intent, load relevant skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

Skills to load (load all applicable skills in a single parallel batch):
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
- **tester**: Use when the task mentions adding or updating tests, or after implementing a feature to ensure proper test coverage
- **reviewer**: Use after implementation is complete to catch bugs, design issues, and maintainability problems before finalizing
- **optimizer**: Use when the task describes performance improvements — profile and implement measurable optimizations
- **auditor**: Use when the task describes security-related changes, authentication flows, or data handling to scan for vulnerabilities

Workflow:
1. Analyze the prompt to categorize the type of work (feature, fix, refactor, test, security, performance, etc.)
2. Load all applicable skills in parallel (always include **code-follower**, add others based on task type)
3. Implement the changes in the current working directory, delegating to the appropriate specialized agents based on the work type — launch independent agents in parallel
4. Run post-implementation agents in parallel where independent (e.g., **reviewer** + **auditor** together, **tester** + **optimizer** together)
5. If the reviewer surfaces problems, use the **fixer** agent to address them (sequential — depends on reviewer output)
6. **Spec cleanup**: If `$ARGUMENTS` references a file in `plans/` (path starts with `plans/` or contains a `.md` file inside `plans/`), delete the consumed spec file after successful implementation. If the `plans/` directory is empty after deletion, remove it too. Note in the final summary: "Removed consumed spec: plans/xyz.md"
