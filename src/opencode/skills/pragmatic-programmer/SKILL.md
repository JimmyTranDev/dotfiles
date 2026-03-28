---
name: pragmatic-programmer
description: Pragmatic Programmer principles including DRY, orthogonality, tracer bullets, broken windows, reversibility, domain languages, and pragmatic paranoia for code quality improvement
---

## Core Principles

| Principle | Rule | Code Smell When Violated |
|-----------|------|--------------------------|
| **DRY** | Every piece of knowledge has a single, unambiguous, authoritative representation | Duplicated logic, copy-pasted code, repeated constants, parallel data structures that must stay in sync |
| **Orthogonality** | Components should be independent — changing one does not affect others | Modifying feature A forces changes in unrelated feature B, tightly coupled modules, global state leaking across boundaries |
| **Reversibility** | Avoid irreversible decisions — keep options open | Hardcoded vendor APIs, framework-specific types leaking into domain logic, concrete implementations where abstractions should be |
| **Tracer Bullets** | Build thin end-to-end slices first, then fill in | Over-designed systems with no working path, layers built bottom-up without integration |
| **Broken Windows** | Fix bad code immediately — neglect accelerates decay | TODO/FIXME accumulation, known bugs left unfixed, inconsistent patterns allowed to spread |
| **Good Enough Software** | Know when to stop — don't over-polish what's already working | Premature optimization, gold-plating features, infinite refactoring loops |
| **Pragmatic Paranoia** | Design by contract, fail early, use assertions | Missing input validation, silent failures, functions that return ambiguous results, catch-all error handlers |

## Design and Architecture

### Design by Contract

- Define clear preconditions, postconditions, and invariants
- Validate inputs at boundaries — fail early with descriptive errors
- Use the type system to enforce contracts where possible

| Pattern | Apply When |
|---------|------------|
| Precondition validation | Function receives external/untrusted input |
| Return type narrowing | Function can fail — use discriminated unions or Result types |
| Assertion guards | Invariant must hold mid-function for correctness |
| Branded/opaque types | Primitive values carry domain meaning (UserId, Email, Currency) |

### Decoupling

- **Law of Demeter**: Only talk to immediate friends — avoid `a.b.c.d` chains
- **Tell, Don't Ask**: Command objects to act instead of querying state and acting externally
- **Event-driven over direct calls**: Use events/callbacks when the caller shouldn't know the handler
- **Shy code**: Modules reveal only what's necessary — minimize public API surface

### Transformations Over Mutation

- Prefer pipelines of data transformations over in-place mutation
- Each step takes input, returns output — no side effects in the middle
- Makes code easier to test, reason about, and parallelize

## Practical Patterns

### Estimating and Scope

- Estimate to communicate feasibility, not to commit
- Break unknowns into smaller knowns — iterate
- Prototype to learn, tracer bullet to build

### Power of Plain Text

- Store data in human-readable formats when durability matters
- Plain text outlives binary formats and proprietary tools
- Config, data interchange, and knowledge stores benefit from text

### Error Handling Hierarchy

| Level | Strategy |
|-------|----------|
| Expected errors | Return typed error values (Result, Either, discriminated unions) |
| Programming errors | Assertions that crash early in development |
| External failures | Retry with backoff, circuit breaker, graceful degradation |
| Impossible states | Make them unrepresentable via the type system |

### Refactoring Triggers

Refactor when you encounter any of these:

- **Duplication** — DRY violation detected
- **Non-orthogonal design** — changes ripple across unrelated modules
- **Outdated knowledge** — code reflects old requirements or assumptions
- **Usage patterns** — actual usage differs from original design intent
- **Performance** — profiling identifies a real bottleneck (not a guess)
- **Broken window** — small quality issues accumulating

### Naming as Documentation

- Names should reveal intent — if you need a comment to explain a variable, rename it
- Functions named after what they do, not how they do it
- Boolean names as questions: `isValid`, `hasPermission`, `canRetry`
- Avoid encodings, abbreviations, and type prefixes

## Anti-Patterns to Detect

| Anti-Pattern | Pragmatic Fix |
|--------------|---------------|
| Programming by coincidence | Understand why code works — test assumptions explicitly |
| Cargo cult coding | Don't copy patterns without understanding their purpose |
| Primitive obsession | Wrap domain concepts in types (Email, UserId, Money) |
| Temporal coupling | Make dependencies explicit — don't rely on execution order |
| Feature envy | Move behavior to the data it operates on |
| Shotgun surgery | Consolidate scattered changes into a single module |
| Speculative generality | Remove abstractions that serve only one case — YAGNI |
| Dead code | Delete it — version control remembers |

## Checklist for Code Review

1. Is every piece of knowledge represented once and only once?
2. Are modules orthogonal — can you change one without affecting others?
3. Are decisions reversible — can you swap implementations without rewriting?
4. Does code fail early with clear errors or silently corrupt state?
5. Are names self-documenting — could you understand the code without comments?
6. Are there broken windows — small quality issues being ignored?
7. Is the code shy — does it expose only what's necessary?
8. Are transformations preferred over mutation?
9. Is the type system used to prevent invalid states?
10. Is there any programming by coincidence — code that works but nobody knows why?
