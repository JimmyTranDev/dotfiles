---
name: typescript-patterns
description: TypeScript coding conventions including error handling, imports, strict null handling, and project setup preferences
---

## Code Rules

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
