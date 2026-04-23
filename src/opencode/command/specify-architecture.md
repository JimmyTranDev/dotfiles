---
name: specify-architecture
description: Analyze project architecture, module boundaries, and structural patterns without making changes and write spec to `spec/`
---

Usage: /specify-architecture [scope or description]

Analyze the project's architecture — structure, module boundaries, dependency direction, coupling, cohesion, and architectural patterns — without making any changes.

$ARGUMENTS

Load the **meta-structure**, **code-quality**, **strategy-pragmatic-programmer**, and **code-conventions** skills in parallel.

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand the tech stack and architecture
   - Run `git log --oneline -30` to understand recent development direction
   - Identify the framework, build system, dependency management approach, and deployment model
   - If the user specifies a scope, narrow analysis to those files or areas

2. If the user specifies a scope or focus area, narrow analysis to that. Otherwise analyze the full codebase.

3. Analyze the architecture across these dimensions (only include dimensions that are relevant):
   - **Project structure**: Directory layout, file organization (feature-based vs type-based), entry points, configuration files. Map the top-level structure and identify the organizational pattern.
   - **Module boundaries**: How is the code divided into modules/packages/layers? Are boundaries clean or leaky? Do modules have clear single responsibilities?
   - **Dependency direction**: Which modules depend on which? Are dependencies flowing in one direction (e.g., UI -> domain -> data) or are there circular dependencies? Are abstractions depended on rather than concretions?
   - **Layer separation**: Are presentation, business logic, and data access cleanly separated? Or are concerns mixed within files/modules?
   - **Coupling assessment**: How tightly coupled are modules? Would changing module A force changes in module B? Are there god objects or god modules that everything depends on?
   - **Cohesion evaluation**: Do modules contain related functionality, or are they grab-bags of unrelated code? Are there files that do too many things?
   - **Architectural pattern identification**: What pattern is in use (MVC, hexagonal, clean architecture, feature-sliced, monolith, microservices, serverless)? Is it applied consistently or partially?
   - **Entry point mapping**: Where does execution start? What are the public APIs, CLI commands, route handlers, or event listeners? How does data flow from entry to exit?
   - **Configuration and environment**: How is configuration managed? Are there multiple environments? Is config separated from code?
   - **Error handling architecture**: Is there a consistent error handling strategy? Error boundaries? Global handlers? Logging infrastructure?
   - **State management**: How is state managed across the application? Local vs global state? Persistence strategy?

4. For each finding:
   - Give it a short, clear name
   - Describe the current state and whether it follows good architectural practices
   - If there's an issue, explain the impact and what a better approach would look like
   - Classify as: strength, concern, or recommendation
   - Include file paths and line numbers where relevant
   - Suggest which `/command` to run to address concerns (e.g., `/improve-consolidate`, `/implement`, `/fix`)

5. Delegate to specialized agents — launch independent agents in parallel:
   - **reviewer**: Analyze code organization, module boundaries, and dependency patterns for architectural soundness
   - **auditor**: Check for security-relevant architectural decisions (exposed internals, missing boundaries, unsafe defaults)

6. Present findings:
   - Do NOT apply any changes — this command is analysis-only
   - Group by dimension from step 3
   - Lead with strengths (what's done well), then concerns, then recommendations
   - Highlight the top 3-5 most impactful architectural improvements
   - Include a dependency graph or module map if the project is complex enough to warrant one

7. Write findings to a spec file:
   - Create the `spec/` directory if it doesn't exist
   - Use the `architecture-` prefix followed by a descriptive kebab-case name based on the scope or key findings (e.g., `spec/architecture-api-layer.md`, `spec/architecture-module-boundaries.md`). If a file with the same name already exists, append a numeric suffix
   - Write all findings using the same grouped-by-dimension format from step 6
   - Include each item's file location, classification, description, and suggested `/command`
   - Print a brief summary to chat: the file path, total number of findings, and the top 3 items
