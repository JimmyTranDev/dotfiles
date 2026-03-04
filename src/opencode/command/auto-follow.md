---
name: auto-follow
description: Check staged or recent changes for pattern consistency against existing codebase conventions using the follower agent
---

Use the follower agent to verify that the current changes follow established codebase conventions.

## Steps

1. Check for staged changes with `git diff --cached`
2. If no staged changes, check recent changes with `git diff HEAD~1`
3. If no changes found, notify the user
4. Scan the surrounding codebase to learn existing patterns
5. Compare the changes against those patterns

## Pattern Check Focus

Use the follower agent to verify:

1. **Naming patterns** - Variable naming (camelCase/snake_case), file naming, component naming
2. **Code structure** - Import organization, function ordering, component patterns, export style
3. **Error handling** - Matches existing try-catch/result type patterns
4. **API patterns** - Consistent with existing fetch/client patterns
5. **TypeScript conventions** - Type vs Interface usage, generic patterns, null handling
6. **File organization** - Matches existing directory structure and co-location patterns
7. **Testing patterns** - Assertion style, mock patterns, test data setup

## Output Format

- **Pattern Violations** - Where new code deviates from existing conventions (with examples of what the pattern should look like)
- **Consistent** - Patterns that correctly match existing code
- **Ambiguous** - Areas where the codebase itself is inconsistent
