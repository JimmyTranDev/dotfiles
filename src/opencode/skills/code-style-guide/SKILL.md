---
name: code-style-guide
description: Cross-language coding standards including naming, formatting, architecture preferences, and the no-comments policy
---

## Core Rules

1. **No comments** — write self-documenting code with clear variable names, function names, and code structure. Comments clutter code, become outdated, and can mislead.
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

### Git
| Thing | Format | Example |
|-------|--------|---------|
| Commit messages | `<emoji> <type>(<scope>): <desc>` | `✨ feat(auth): add login flow` |
| Branch names | `JIRA-ID-kebab-case` | `BW-123-add-login` |

## File Organization

### TypeScript Projects
Split modules into up to 6 files:
- `index.ts` — main logic & public exports
- `types.ts` — TypeScript types/interfaces (no runtime code)
- `consts.ts` — constants & configuration
- `utils.ts` — pure utility functions
- `classes.ts` — class definitions
- `hooks.ts` — React hooks

### Shell Projects
```
scripts/
  common/       # Shared libraries (sourced, not run directly)
  install/      # Platform-specific installers
  worktrees/    # Full CLI tool with modular architecture
    worktree    # Entry point (no .sh extension)
    config.sh   # Constants
    lib/        # Reusable modules
    commands/   # Subcommand implementations
  *.sh          # Standalone scripts
```

## Styling

- **Tailwind CSS** utility classes over custom CSS
- Mobile-first responsive: base -> `md:` -> `lg:`
- Use `cn()` for conditional class merging
- No inline `style` except dynamic values
- **Catppuccin Mocha** as the unified theme across all tools

## Architecture Preferences

- **DRY**: Extract shared logic when it appears 3+ times
- **KISS**: Replace complex solutions with simpler alternatives
- **YAGNI**: Remove speculative features and unused abstractions
- **Composition over inheritance**
- **Small, focused functions** — each does one thing
- **Derive state** — never duplicate data that can be computed
- **Direct imports** over barrel file re-exports when possible

## Error Handling

### TypeScript
- Throw for exceptional cases, result types for expected failures
- Always handle async errors
- Never swallow errors silently
- Meaningful error messages

### Shell
- `set -e` for standalone scripts
- `command -v` for tool existence (never `which`)
- Inline `|| { error; return 1 }` for sourced libraries
- `trap` for cleanup

## Testing

- Test behavior, not implementation
- Descriptive test names: "applies 20% discount for orders over $100"
- AAA pattern: Arrange, Act, Assert
- Mock external dependencies, not your own code
- Prefer Vitest for TypeScript projects

## What to Avoid

- Comments in code
- Generated docs/README files
- Premature optimization
- Over-engineering / unnecessary abstractions
- Copy-pasting code (extract shared utilities)
- Barrel files that cause circular dependencies
- Inline styles in React components
- `var` in JavaScript
- `which` in shell scripts
