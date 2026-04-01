---
name: conventions
description: Coding conventions covering general principles, conditional complexity, error handling, and TypeScript-specific patterns including module structure, imports, and project setup
---

## General

- Avoid nested `else if` chains — use early returns, guard clauses, or `switch` to reduce cognitive complexity
- Never swallow errors silently
- Provide meaningful error messages

## TypeScript

### Code Rules

- Use strict null handling — always handle `null`/`undefined` cases
- Prefer `const` over `let`, never use `var`
- Prefer arrow functions for callbacks and simple functions
- Use template literals over string concatenation

### Naming

- Use camelCase for files, folders, variables, functions, and properties
- Use PascalCase for types, interfaces, enums, and React components
- Use SCREAMING_SNAKE_CASE for constants and environment variables

### Module Structure

- Components and hooks each get their own folder with `index.tsx` as the entry point
- Supporting files live alongside the entry point: `utils.ts`, `hooks.ts`, `consts.ts`, `types.ts`

```
components/
  userCard/
    index.tsx
    types.ts
    consts.ts
    utils.ts
  searchInput/
    index.tsx
    types.ts
    hooks.ts

hooks/
  useDebounce/
    index.ts
    types.ts
  useAuth/
    index.ts
    utils.ts
    consts.ts
```

### Error Handling

- Throw errors for exceptional cases, return result types for expected failures
- Always handle async errors with try/catch or `.catch()`

### Imports

- External packages first, then internal modules
- Group imports by source (external, internal, relative)
- Prefer direct imports over barrel file re-exports when possible

### Project Setup Preferences

- **Package manager**: Prefer `pnpm` for projects, `bun` for scripts/tooling
- **Bundler**: Vite preferred
- **Linting**: ESLint + Prettier or Biome
- **Testing**: Vitest preferred
