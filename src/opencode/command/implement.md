---
name: implement
description: Implement the required changes described in the user's prompt
---

Read the user's prompt and implement the required changes described in it.

1. Parse the prompt to understand what needs to be implemented
2. Check if the changes described are already present in the codebase
3. If the changes are missing or incomplete, implement them according to the description
4. If the changes are already present, verify they match the description and suggest improvements if needed

After understanding the intent, delegate to specialized agents in parallel where applicable:

- **convention-matcher**: Always use first to study existing codebase conventions (naming, imports, file structure, patterns) so all new code matches the established style
- **file-organizer**: Use when the task describes adding new modules, reorganizing files, or restructuring project layout
- **designer**: Use when the task describes UI component work, accessibility improvements, or frontend feature additions
- **fixer**: Use when the task describes a bug fix — let it trace the root cause and apply the minimal surgical fix
- **solver**: Use when the task describes a complex or multi-layered problem where the cause is unclear and deeper investigation is needed
- **tester**: Use when the task mentions adding or updating tests, or after implementing a feature to ensure proper test coverage
- **reviewer**: Use after implementation is complete to catch bugs, design issues, and maintainability problems before finalizing
- **logic-checker**: Use when the task involves business logic, state machines, or complex conditional flows to verify logical soundness and catch impossible states
- **deduplicator**: Use when the task describes extracting shared utilities or reducing duplication across the codebase
- **simplifier**: Use when the task describes refactoring or simplification work — apply DRY, KISS, YAGNI principles
- **optimizer**: Use when the task describes performance improvements — profile and implement measurable optimizations
- **auditor**: Use when the task describes security-related changes, authentication flows, or data handling to scan for vulnerabilities
- **import-optimizer**: Use when the task describes cleaning up barrel files, fixing circular dependencies, or optimizing imports
- **prompt-writer**: Use when the task describes writing or updating AI system prompts or agent instructions

Workflow:
1. Analyze the prompt to categorize the type of work (feature, fix, refactor, test, security, performance, etc.)
2. Run the **convention-matcher** agent to learn codebase conventions
3. Implement the changes, delegating to the appropriate specialized agents based on the work type
4. Run the **reviewer** agent on the completed implementation to catch issues
5. If the reviewer surfaces problems, use the **fixer** agent to address them