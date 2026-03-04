---
name: auto-review
description: Auto review staged or recent changes for bugs, design issues, and security using the reviewer agent
---

Use the reviewer agent to perform a thorough code review on the current changes.

## Steps

1. Check for staged changes with `git diff --cached`
2. If no staged changes, check recent changes with `git diff HEAD~1`
3. If no changes found, notify the user

## Review Focus

Use the reviewer agent to analyze:

1. **Correctness** - Logic errors, off-by-one bugs, null/undefined handling, edge cases, race conditions
2. **Security** - Injection vulnerabilities, XSS, authentication bypasses, secrets in code
3. **Design** - SOLID violations, unnecessary complexity, tight coupling, poor separation of concerns
4. **Performance** - N+1 queries, memory leaks, unnecessary re-renders, blocking async operations
5. **Maintainability** - Unclear naming, hidden side effects, untestable code

## Output Format

Organize findings by severity:
- **Critical** - Must fix before merge (with line numbers and fix suggestions)
- **Important** - Should fix (with explanation of why)
- **Minor** - Consider fixing
- **Good Patterns** - Positive patterns worth highlighting
