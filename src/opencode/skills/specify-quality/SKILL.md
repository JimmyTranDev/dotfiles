---
name: specify-quality
description: Specify skill for code quality analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`quality-`

## Skills to Load

- **code-follower**: Match existing codebase conventions
- **code-simplifier**: Code smell detection and simplification patterns
- **code-deduplicator**: Extracting repeated patterns into reusable utilities
- **code-conventions**: Coding conventions and module structure
- **strategy-pragmatic-programmer**: DRY, orthogonality, KISS, YAGNI
- **code-consolidator**: Merging over-separated code (optional)
- **code-logic-checker**: Finding logical gaps (optional)
- **ts-total-typescript**: TypeScript patterns (optional)
- **tool-eslint-config**: Linting configuration (optional)
- **meta-shell-scripting**: Shell scripting conventions (optional)

## Agents to Launch

- **reviewer**: Analyze code for correctness issues, design problems, and maintainability concerns
- **auditor**: Scan for security vulnerabilities that overlap with quality issues

## Analysis Categories

- **Naming clarity**: Vague variable/function names, inconsistent naming conventions, misleading identifiers
- **Function design**: Functions doing too much, unclear responsibilities, deeply nested logic, high cyclomatic complexity
- **Duplication**: Repeated patterns, copy-pasted logic, similar implementations that should be unified via DRY
- **Over-engineering**: Premature abstractions, unnecessary indirection, wrapper functions that add no value — apply KISS and YAGNI
- **Type safety**: Loose types, `any` usage, unsafe casts, missing discriminated unions, overly broad generics
- **Dead code**: Unused exports, unreachable branches, deprecated patterns still in place, vestigial parameters
- **Module structure**: Tight coupling, poor cohesion, circular dependencies, barrel file bloat, unclear dependency direction
- **Architecture**: Mixed abstraction levels, leaky abstractions, god objects, violation of single responsibility
- **Simplification**: Deeply nested conditionals that could use early returns, imperative loops replaceable with declarative transforms, state management with unnecessary intermediaries, trivial single-use abstractions that add indirection

## Severity Classification

Rank by code quality impact (high, medium, low) considering:
- Readability gain
- Maintenance burden reduction
- Risk of change

For each finding, identify which principle it violates (DRY, KISS, YAGNI, SRP, etc.).

## Scope Overrides

None — uses default scope detection.
