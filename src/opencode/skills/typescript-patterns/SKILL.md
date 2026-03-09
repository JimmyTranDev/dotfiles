---
name: typescript-patterns
description: TypeScript coding conventions including module structure, naming, error handling, and project setup preferences
---

## Module Structure

Split code into separate files by concern. A module can have up to 6 files:

```
feature/
├── index.ts      # Main logic & public exports (required)
├── types.ts      # TypeScript interfaces & types (no runtime code)
├── consts.ts     # Constants & configuration (no functions)
├── utils.ts      # Pure utility functions (no side effects)
├── classes.ts    # Class definitions
└── hooks.ts      # React hooks (if applicable)
```

Only create files that have content. Don't create empty files.

### Decision Tree

| Content | File |
|---------|------|
| TypeScript type/interface | `types.ts` |
| Constant, enum, or config value | `consts.ts` |
| Pure function with no side effects | `utils.ts` |
| Class | `classes.ts` |
| React hook | `hooks.ts` |
| Main feature logic or public API | `index.ts` |

## Naming Conventions

- **Variables/functions**: `camelCase`
- **Types/interfaces**: `PascalCase`
- **Constants**: `SCREAMING_SNAKE_CASE` for true constants, `camelCase` for config objects
- **Files**: `kebab-case` for standalone files, feature name for module directories
- **Components**: `PascalCase` file names matching component name

## Code Rules

- **No comments** — write self-documenting code with clear naming
- **Minimum code** — write the smallest amount of readable code to satisfy the requirement
- **Match existing style** — follow the conventions already in the codebase
- Prefer `type` over `interface` unless extending or implementing
- Use strict null handling — always handle `null`/`undefined` cases
- Prefer `const` over `let`, never use `var`
- Prefer arrow functions for callbacks and simple functions
- Use template literals over string concatenation

## Error Handling

- Throw errors for exceptional cases, return result types for expected failures
- Always handle async errors with try/catch or `.catch()`
- Never swallow errors silently
- Provide meaningful error messages

## Imports

- External packages first, then internal modules
- Group imports by source (external, internal, relative)
- Prefer direct imports over barrel file re-exports when possible

## Project Setup Preferences

- **Package manager**: Prefer `pnpm` for projects, `bun` for scripts/tooling
- **Bundler**: Vite preferred
- **Linting**: ESLint + Prettier or Biome
- **Testing**: Vitest preferred
