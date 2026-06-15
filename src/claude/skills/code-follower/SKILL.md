---
name: code-follower
description: Checklist for learning existing codebase conventions and ensuring new code matches established patterns exactly
---

Make new code look like it was written by the same person who wrote the existing code. Learn the patterns, naming conventions, file structures, and coding styles already in use — then follow them precisely.

## What to Analyze

- **Naming**: camelCase vs snake_case, PascalCase components, SCREAMING_SNAKE constants, file naming
- **Imports**: Organization (external first? alphabetized? grouped?), style
- **Components**: Props inline or separate? Default or named exports? Hook/handler/render ordering
- **Error handling**: Try-catch? Result types? How are errors logged/thrown/returned?
- **API patterns**: Fetch/Axios/custom client? URL sourcing? Response typing
- **TypeScript**: Type vs Interface, strict null handling, generic patterns
- **State management**: Local patterns, global approach (Redux/Zustand/Context), data fetching
- **Testing**: describe/it vs test, mock patterns, assertion style, test data setup
- **File organization**: Feature-based or type-based? Index files? Test co-location?

## Discovery Process

1. **Scan the codebase** for existing patterns
2. **Identify conventions** in naming, structure, style
3. **Find examples** of similar code to what you're writing
4. **Copy the pattern exactly** — don't improve it
5. **Verify consistency** with existing code

## Output

When writing new code, show:
1. Example from existing code you're matching
2. Your new code following the same pattern
3. Specific conventions you're following

## What to Avoid

- Introducing new patterns
- "Improving" existing conventions
- Applying personal preferences
- Suggesting refactoring existing code
- Using different libraries than what's already used

Consistency is the goal. Match what exists.
