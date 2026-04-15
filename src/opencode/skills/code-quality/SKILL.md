---
name: code-quality
description: Code quality analysis categories, prioritization framework, assessment checklists, and cross-references to specialized refactoring skills
---

Structured approach to assessing and improving internal code quality — structure, readability, and maintainability — without changing behavior.

## Quality Analysis Categories

| Category | What to Look For | Specialized Skill |
|----------|-----------------|-------------------|
| Naming clarity | Vague variable/function names, inconsistent conventions, misleading identifiers | **strategy-pragmatic-programmer** (Naming as Documentation) |
| Function design | Functions doing too much, unclear responsibilities, deep nesting, high cyclomatic complexity | **code-simplifier** (Code Smell Detection, Complexity Reduction) |
| Duplication | Repeated patterns, copy-pasted logic, similar implementations that should be unified | **code-deduplicator** (extraction rules and process) |
| Over-engineering | Premature abstractions, unnecessary indirection, wrappers that add no value | **code-consolidator** (inlining, layer collapsing) |
| Type safety | Loose types, `any` usage, unsafe casts, missing discriminated unions, overly broad generics | **ts-total-typescript** |
| Dead code | Unused exports, unreachable branches, deprecated patterns, vestigial parameters | **code-simplifier** (Structural Smells) |
| Module structure | Tight coupling, poor cohesion, circular dependencies, barrel file bloat, unclear dependency direction | **code-consolidator** (file/layer decisions) |
| Architecture | Mixed abstraction levels, leaky abstractions, god objects, single responsibility violations | **strategy-pragmatic-programmer** (Orthogonality, Decoupling) |

## Prioritization Framework

| Priority | Criteria | Action |
|----------|----------|--------|
| Critical | Blocks feature work, causes bugs, or corrupts data | Fix immediately |
| High | Duplicated logic (3+), deeply nested code, god objects | Fix in current session |
| Medium | Inconsistent naming, loose types, minor coupling issues | Fix if touching the file |
| Low | Style preferences, single-use minor improvements | Track for later |
| Skip | Working code that is rarely read or changed | Leave it alone |

### Impact Scoring

| Factor | High Impact | Low Impact |
|--------|-------------|------------|
| Frequency | Code is read/modified weekly | Code hasn't changed in months |
| Blast radius | Change affects many modules | Change is isolated |
| Bug risk | Pattern has caused bugs before | Pattern is stable |
| Readability | Takes > 30 seconds to understand | Intent is clear |
| Onboarding | New developers struggle with it | Easy to follow |

## Assessment Checklist

### Naming

- [ ] Can you understand each variable's purpose without reading surrounding code?
- [ ] Do function names describe what they do, not how?
- [ ] Are booleans named as questions (`isValid`, `hasPermission`, `canRetry`)?
- [ ] Are naming conventions consistent within each module?
- [ ] Are abbreviations avoided or universally understood?

### Function Design

- [ ] Is every function under 20 lines (excluding type definitions)?
- [ ] Does each function have a single clear responsibility?
- [ ] Is nesting depth 2 levels or less?
- [ ] Are guard clauses used instead of deeply nested conditionals?
- [ ] Do functions take 3 or fewer parameters (or use an options object)?

### Duplication

- [ ] Are there patterns repeated 3+ times that could be extracted?
- [ ] Are there near-identical implementations with slight variations?
- [ ] Is shared logic in a discoverable, well-named location?

### Over-Engineering

- [ ] Are all abstractions used by 2+ consumers?
- [ ] Do wrapper functions add meaningful logic beyond delegation?
- [ ] Are there layers that only pass through to the next layer?
- [ ] Could a simpler implementation achieve the same result?

### Type Safety

- [ ] Is `any` absent or justified with a comment explaining why?
- [ ] Are type assertions (`as`) minimized and necessary?
- [ ] Do union types use discriminated unions for safe narrowing?
- [ ] Are generics constrained appropriately (not `<T>` when `<T extends X>` fits)?

### Dead Code

- [ ] Are all exports consumed by at least one module?
- [ ] Are all branches reachable?
- [ ] Are there deprecated patterns still in use?
- [ ] Are there parameters that are always passed the same value?

### Module Structure

- [ ] Can each module be understood independently?
- [ ] Are there circular dependencies?
- [ ] Do modules depend on abstractions, not concrete implementations?
- [ ] Are related files co-located?

### Architecture

- [ ] Does each module operate at a single abstraction level?
- [ ] Are internal details hidden behind clean interfaces?
- [ ] Can implementations be swapped without rewriting consumers?
- [ ] Are domain concepts separated from infrastructure concerns?

## Quality Smell Quick Reference

| Smell | Category | Typical Fix |
|-------|----------|-------------|
| `any` type | Type safety | Add proper types, use `unknown` + narrowing |
| 50+ line function | Function design | Extract concerns into named functions |
| 3+ deep nesting | Function design | Guard clauses, early returns |
| Copy-pasted block | Duplication | Extract shared utility |
| Wrapper with no logic | Over-engineering | Inline or delete |
| Unused export | Dead code | Delete it |
| Module importing 10+ files | Module structure | Check cohesion, consider splitting |
| Business logic in UI layer | Architecture | Move to domain/service layer |
| `result.data.user.settings.theme` | Architecture | Law of Demeter — reduce chain depth |
| Magic numbers/strings | Naming | Extract named constants |

## What This Skill Does NOT Cover

- Detailed refactoring patterns and code smell catalogs — load the **code-simplifier** skill
- DRY extraction process and rules — load the **code-deduplicator** skill
- Inlining over-separated code — load the **code-consolidator** skill
- Design principles (DRY, orthogonality, reversibility) — load the **strategy-pragmatic-programmer** skill
- Logic correctness (contradictions, invalid assumptions) — load the **code-logic-checker** skill
- TypeScript-specific patterns (generics, branded types) — load the **ts-total-typescript** skill
- ESLint configuration — load the **tool-eslint-config** skill
- Shell script conventions — load the **meta-shell-scripting** skill
