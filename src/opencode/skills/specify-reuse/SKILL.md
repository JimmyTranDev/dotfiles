---
name: specify-reuse
description: Specify skill for code reuse analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`reuse-`

## Skills to Load

- **code-deduplicator**: Extracting repeated patterns into reusable utilities
- **code-consolidator**: Merging over-separated code
- **code-follower**: Match existing codebase conventions
- **code-simplifier**: Simplification patterns (optional)
- **strategy-pragmatic-programmer**: DRY and orthogonality (optional)
- **meta-structure**: Project directory layout (optional)

## Agents to Launch

- **reviewer**: Verify extraction and merge suggestions are correct and won't break existing behavior

## Analysis Categories

### Duplication (code that should be shared)

- **Exact duplicates**: Identical or near-identical code blocks in multiple files
- **Structural duplicates**: Different variable names but same logic shape, control flow, or algorithm
- **Similar patterns**: Repeated sequences (fetch-then-transform, validate-then-save, try-catch-log) that could be a shared utility
- **Repeated type definitions**: Identical or overlapping interfaces/types/schemas in multiple places
- **Copy-pasted components**: UI components with same structure but minor prop/style differences
- **Reimplemented utilities**: Custom code duplicating functionality in project dependencies or stdlib

### Abstraction (code that needs a named concept)

- **Missing abstractions**: Multiple call sites performing the same multi-step workflow inline
- **Ungeneralized solutions**: Code handling one specific case but could be parameterized for related cases
- **Cross-cutting concerns**: Logging, error handling, auth checks, validation repeated ad-hoc
- **Parallel hierarchies**: Mirrored file/class structures that change together

### Over-separation (code that should be merged)

- **Thin files**: Files with < 20 lines of actual logic
- **Single-use wrappers**: Functions/components wrapping another with no added logic
- **Pass-through layers**: Modules forwarding calls without transformation
- **Fragmented configs**: Related settings scattered across multiple files
- **One-item directories**: Directories containing a single file
- **Premature splits**: Features split into files before complexity warrants it
- **Trivial abstractions**: Helpers called once with 1-3 line bodies

### Consolidation Decision Tree

- Confirm pieces are not independently consumed/tested by different parts
- Verify merged result stays under 200 lines
- Check that merging won't combine genuinely different concerns
- Check files don't have different change frequencies

## Severity Classification

Rank by:
- Number of occurrences
- Estimated lines saved / maintenance burden reduced
- Risk level: low (mechanical extraction), medium (minor refactoring), high (interface changes)

## Scope Overrides

None — uses default scope detection.
