---
name: implement
description: Implement the required changes described in the user's prompt
---

Usage: /implement <description of what to implement>

Implement the required changes described below:

$ARGUMENTS

1. Parse the prompt to understand what needs to be implemented
2. Check if the changes described are already present in the codebase
3. If the changes are missing or incomplete, implement them according to the description
4. If the changes are already present, verify they match the description and suggest improvements if needed

After understanding the intent, load relevant skills and delegate to specialized agents in parallel where applicable:

Skills to load for guidance:
- **convention-matcher**: Always load first to study existing codebase conventions (naming, imports, file structure, patterns) so all new code matches the established style
- **file-organizer**: Load when the task describes adding new modules, reorganizing files, or restructuring project layout
- **logic-checker**: Load when the task involves business logic, state machines, or complex conditional flows to verify logical soundness and catch impossible states
- **deduplicator**: Load when the task describes extracting shared utilities or reducing duplication across the codebase
- **simplifier**: Load when the task describes refactoring or simplification work — apply DRY, KISS, YAGNI principles
- **import-optimizer**: Load when the task describes cleaning up barrel files, fixing circular dependencies, or optimizing imports
- **prompt-writer**: Load when the task describes writing or updating AI system prompts or agent instructions

Agents to delegate to:
- **designer**: Use when the task describes UI component work, accessibility improvements, or frontend feature additions
- **fixer**: Use when the task describes a bug fix — let it trace the root cause and apply the minimal surgical fix
- **solver**: Use when the task describes a complex or multi-layered problem where the cause is unclear and deeper investigation is needed
- **tester**: Use when the task mentions adding or updating tests, or after implementing a feature to ensure proper test coverage
- **reviewer**: Use after implementation is complete to catch bugs, design issues, and maintainability problems before finalizing
- **optimizer**: Use when the task describes performance improvements — profile and implement measurable optimizations
- **auditor**: Use when the task describes security-related changes, authentication flows, or data handling to scan for vulnerabilities

Workflow:
1. **Create a worktree** following the Worktree Workflow in AGENTS.md — name the branch after the feature being implemented
2. Analyze the prompt to categorize the type of work (feature, fix, refactor, test, security, performance, etc.)
3. Load the **convention-matcher** skill to learn codebase conventions
4. Implement the changes in the worktree, delegating to the appropriate specialized agents based on the work type
5. Run the **reviewer** agent on the completed implementation to catch issues
6. If the reviewer surfaces problems, use the **fixer** agent to address them
7. **Commit, merge, and clean up** the worktree following the Worktree Workflow in AGENTS.md