---
name: specify-architecture
description: Specify skill for architecture analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`architecture-`

## Skills to Load

- **meta-structure**: Project directory layout and architectural organization
- **code-quality**: Code quality analysis and prioritization
- **strategy-pragmatic-programmer**: DRY, orthogonality, and design principles
- **code-conventions**: Coding conventions and module structure

## Agents to Launch

- **reviewer**: Analyze code organization, module boundaries, and dependency patterns for architectural soundness
- **auditor**: Check for security-relevant architectural decisions (exposed internals, missing boundaries, unsafe defaults)

## Analysis Categories

- **Project structure**: Directory layout, file organization (feature-based vs type-based), entry points, configuration files. Map the top-level structure and identify the organizational pattern.
- **Module boundaries**: How is the code divided into modules/packages/layers? Are boundaries clean or leaky? Do modules have clear single responsibilities?
- **Dependency direction**: Which modules depend on which? Are dependencies flowing in one direction (UI -> domain -> data) or are there circular dependencies? Are abstractions depended on rather than concretions?
- **Layer separation**: Are presentation, business logic, and data access cleanly separated? Or are concerns mixed within files/modules?
- **Coupling assessment**: How tightly coupled are modules? Would changing module A force changes in module B? Are there god objects or god modules that everything depends on?
- **Cohesion evaluation**: Do modules contain related functionality, or are they grab-bags of unrelated code? Are there files that do too many things?
- **Architectural pattern identification**: What pattern is in use (MVC, hexagonal, clean architecture, feature-sliced, monolith, microservices, serverless)? Is it applied consistently or partially?
- **Entry point mapping**: Where does execution start? What are the public APIs, CLI commands, route handlers, or event listeners? How does data flow from entry to exit?
- **Configuration and environment**: How is configuration managed? Are there multiple environments? Is config separated from code?
- **Error handling architecture**: Is there a consistent error handling strategy? Error boundaries? Global handlers? Logging infrastructure?
- **State management**: How is state managed across the application? Local vs global state? Persistence strategy?

## Severity Classification

Each finding is classified as:
- **Strength**: Good architectural practice in place
- **Concern**: Architectural issue with measurable impact
- **Recommendation**: Improvement opportunity

## Scope Overrides

None — uses default scope detection.
