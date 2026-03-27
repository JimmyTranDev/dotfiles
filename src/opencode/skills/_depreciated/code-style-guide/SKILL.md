---
name: code-style-guide
description: Cross-language coding standards including naming, formatting, architecture preferences, and the no-comments policy
---

## Core Rules

1. **No comments** — write self-documenting code with clear variable names, function names, and code structure.
2. **Minimum code** — write the smallest amount of readable code necessary to satisfy the requirement.
3. **Match existing style** — follow the conventions already in the codebase. Don't introduce new patterns.
4. **No generated documentation** — don't create README, docs, or markdown files unless explicitly asked.

## Naming Conventions

### TypeScript / JavaScript
| Thing | Case | Example |
|-------|------|---------|
| Variables / functions | `camelCase` | `getUserById`, `isValid` |
| Types / interfaces | `PascalCase` | `UserProfile`, `ApiResponse` |
| React components | `PascalCase` | `UserCard`, `SearchInput` |
| True constants | `SCREAMING_SNAKE` | `MAX_RETRIES`, `API_BASE_URL` |
| Config objects | `camelCase` | `defaultConfig` |
| Files (non-component) | `kebab-case` | `user-service.ts`, `api-client.ts` |
| Component files | `PascalCase` | `UserCard.tsx` |

### Shell Scripts
| Thing | Case | Example |
|-------|------|---------|
| Global constants | `UPPERCASE_SNAKE` | `DOTFILES_DIR`, `REQUIRED_TOOLS` |
| Local variables | `lowercase_snake` | `branch_name`, `success_count` |
| Functions | `lowercase_snake` | `get_org_dirs`, `cmd_create` |
| Exported env vars | `UPPERCASE_SNAKE` | `MANPAGER`, `FZF_DEFAULT_OPTS` |

## TypeScript Conventions

- Use strict null handling — always handle `null`/`undefined` cases
- Prefer `const` over `let`, never use `var`
- Prefer arrow functions for callbacks and simple functions
- Use template literals over string concatenation
- Avoid nested `else if` chains — use early returns, guard clauses, or `switch`

## Architecture Preferences

- **DRY**: Extract shared logic when it appears 3+ times
- **KISS**: Replace complex solutions with simpler alternatives
- **YAGNI**: Remove speculative features and unused abstractions
- **Composition over inheritance**
- **Small, focused functions** — each does one thing
- **Derive state** — never duplicate data that can be computed
- **Direct imports** over barrel file re-exports when possible
- **Catppuccin Mocha** as the unified theme across all tools

## Project Setup Preferences

- **Package manager**: Prefer `pnpm` for projects, `bun` for scripts/tooling
- **Bundler**: Vite preferred
- **Linting**: ESLint + Prettier or Biome
- **Testing**: Vitest preferred

## Domain-Specific Details

For detailed conventions on specific domains, load the relevant skill:

| Domain | Skill |
|--------|-------|
| File organization (6-file structure) | `file-organizer` |
| Shell scripting (error handling, patterns) | `shell-scripting` |
| Git commits, branches, PRs | `git-workflows` |
| React components, styling, hooks | `react-patterns` |
| Testing patterns, coverage | `test-coverage` |
| Accessibility | `accessibility` |
| Animations | `ux-ui-animator` |

## What to Avoid

- Comments in code
- Generated docs/README files
- Premature optimization
- Over-engineering / unnecessary abstractions
- Copy-pasting code (extract shared utilities)
- Barrel files that cause circular dependencies
- Inline styles in React components
