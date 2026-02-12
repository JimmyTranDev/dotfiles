---
name: review
description: Auto review code for quality, correctness, and pattern consistency using reviewer and follower agents
---

Run a comprehensive auto review on the current changes using both the reviewer and follower agents.

## Reviewer Analysis

Use the reviewer agent to check:

1. **Correctness** - Logic errors, edge cases, null handling, race conditions
2. **Security** - Injection vulnerabilities, XSS, authentication bypasses
3. **Design Quality** - SOLID violations, unnecessary complexity, tight coupling
4. **Performance** - N+1 queries, memory leaks, unnecessary re-renders
5. **Maintainability** - Unclear naming, hidden side effects, untestable code

## Follower Analysis

Use the follower agent to check:

1. **Naming patterns** - camelCase vs snake_case, PascalCase components, file naming
2. **Code structure** - import organization, function ordering, component patterns
3. **Consistency** - error handling, API patterns, state management approach
4. **Pattern deviations** - identify where new code doesn't match existing conventions

## What to Review

If no specific files are provided, review the staged changes (git diff --cached) or recent changes (git diff HEAD~1).

## Output Format

Organize findings by severity:
- **Critical** - Must fix before merge
- **Important** - Should fix
- **Minor** - Consider fixing
- **Pattern Violations** - Deviations from codebase conventions
- **Good Patterns** - Positive patterns noticed
