---
name: knip
description: Knip unused code linter covering CLI arguments, configuration, issue types, auto-fix, production mode, monorepo workspaces, and troubleshooting
---

## Overview

Knip finds unused files, dependencies, and exports in TypeScript/JavaScript projects. Install as a dev dependency (`npm install -D knip typescript @types/node`) or run without installing (`pnpm dlx knip`).

- Requires Node.js v20.19.0+ or Bun
- Config files: `knip.json`, `knip.jsonc`, `.knip.json`, `.knip.jsonc`, `knip.js`, `knip.ts`, or `package.json#knip`
- JSON schema: `https://unpkg.com/knip@6/schema.json`
- 143 built-in plugins for automatic tool detection

## CLI Arguments

### Mode

| Flag | Description |
|------|-------------|
| `--production` | Lint only production source files (excludes tests, stories, devDependencies) |
| `--strict` | Isolate workspaces, direct dependencies only (implies `--production`) |
| `--cache` | Enable caching (10-40% faster consecutive runs) |
| `--cache-location <path>` | Custom cache location (default: `node_modules/.cache/knip`) |
| `--include-entry-exports` | Report unused exports in entry files |
| `--no-gitignore` | Ignore `.gitignore` files |
| `--watch` | Watch mode, update on file changes |

### Scope & Filtering

| Flag | Description |
|------|-------------|
| `--include <types>` | Report only specified issue types (comma-separated or repeated) |
| `--exclude <types>` | Exclude specified issue types from report |
| `--dependencies` | Shortcut: `dependencies,unlisted,binaries,unresolved,catalog` |
| `--exports` | Shortcut: `exports,nsExports,types,nsTypes,enumMembers,namespaceMembers,duplicates` |
| `--files` | Shortcut: `files` |
| `--tags <tags>` | Include (`+`) or exclude (`-`) tagged exports (e.g. `--tags=-internal`) |
| `--workspace <filter>` / `-W` | Filter to specific workspace(s) by name or path glob |
| `--directory <dir>` | Run from a different directory |

### Auto-fix

| Flag | Description |
|------|-------------|
| `--fix` | Remove unused exports, dependencies, enum members |
| `--fix --allow-remove-files` | Also remove unused files |
| `--fix-type <types>` | Fix only specific types: `dependencies`, `exports`, `types`, `files`, `catalog` |
| `--fix --format` | Format modified files using project formatter (Biome/Prettier/dprint) |

### Output

| Flag | Description |
|------|-------------|
| `--reporter <name>` | `symbols` (default), `compact`, `json`, `markdown`, `codeowners`, `codeclimate`, `disclosure`, `github-actions` |
| `--reporter-options <json>` | Extra options as JSON string |
| `--no-config-hints` | Suppress configuration hints |
| `--treat-config-hints-as-errors` | Exit code 1 on config hints |
| `--max-issues <n>` | Max issues before non-zero exit (default: 0) |
| `--max-show-issues <n>` | Max issues per type to display |
| `--no-exit-code` | Always exit 0 |
| `--no-progress` / `-n` | Disable progress output |

### Troubleshooting

| Flag | Description |
|------|-------------|
| `--debug` / `-d` | Verbose output (workspaces, plugins, globs, resolved files) |
| `--trace` | Trace where exports are imported |
| `--trace-file <path>` | Trace specific file's exports |
| `--trace-export <name>` | Trace specific export name |
| `--trace-dependency <name>` | Trace where a dependency is referenced (supports regex) |
| `--performance` | Show execution time of internal functions |
| `--memory` | Show memory usage after run |

## Issue Types

| Key | Description | Fixable |
|-----|-------------|---------|
| `files` | Unused files | yes |
| `dependencies` | Unused dependencies / devDependencies | yes |
| `unlisted` | Used dependencies not in package.json | no |
| `binaries` | Binaries from unlisted dependencies | no |
| `unresolved` | Unresolvable import specifiers | no |
| `exports` | Unused exports | yes |
| `types` | Unused exported types/interfaces/enums | yes |
| `nsExports` | Exports in used namespace (not included by default) | yes |
| `nsTypes` | Types in used namespace (not included by default) | yes |
| `enumMembers` | Unused exported enum members | yes |
| `namespaceMembers` | Unused exported namespace members | yes |
| `duplicates` | Exports declared more than once | no |
| `catalog` | Unused pnpm catalog entries | yes |

## Configuration

```json
{
  "$schema": "https://unpkg.com/knip@6/schema.json",
  "entry": ["src/index.ts", "scripts/*.ts"],
  "project": ["src/**/*.ts", "scripts/**/*.ts"],
  "paths": {
    "@lib": ["./lib/index.ts"],
    "@lib/*": ["./lib/*"]
  },
  "ignore": ["!src/dir/**"],
  "ignoreBinaries": ["zip", "docker-compose"],
  "ignoreDependencies": ["hidden-package", "@org/.+"],
  "ignoreFiles": ["src/generated/**"],
  "ignoreMembers": ["render", "on.+"],
  "ignoreUnresolved": ["#virtual/.+"],
  "ignoreExportsUsedInFile": true,
  "includeEntryExports": true,
  "rules": {
    "files": "error",
    "dependencies": "error",
    "exports": "warn",
    "types": "warn",
    "duplicates": "off"
  },
  "include": ["files", "dependencies"],
  "exclude": ["enumMembers"],
  "tags": ["-internal", "-lintignore"]
}
```

### Plugin Overrides

```json
{
  "mocha": {
    "config": "config/mocha.config.js",
    "entry": ["**/*.spec.js"]
  },
  "playwright": true,
  "webpack": false
}
```

### Production Mode

Suffix entry/project patterns with `!` for production code:

```json
{
  "entry": ["src/index.ts!", "build/script.js"],
  "project": ["src/**/*.ts!", "build/*.js"]
}
```

Run with `knip --production`. Excludes test files, stories, config files, and devDependencies.

`--strict` implies `--production` and additionally isolates workspace dependencies.

## Monorepo Workspaces

Knip reads workspaces from `package.json#workspaces`, `pnpm-workspace.yaml`, or knip config.

```json
{
  "workspaces": {
    ".": {
      "entry": "scripts/*.js",
      "project": "scripts/**/*.js"
    },
    "packages/*": {
      "entry": "{index,cli}.ts",
      "project": "**/*.ts"
    },
    "packages/cli": {
      "entry": "bin/cli.js"
    }
  }
}
```

Filter workspaces:

```bash
knip --workspace packages/my-lib
knip --workspace @myorg/my-lib
knip --workspace '@myorg/*' --workspace '!@myorg/legacy'
```

Root `entry`/`project` options are ignored when workspaces are configured — use `"."` workspace instead.

## Rules Configuration

| Value | Printed | Counted | Use |
|-------|---------|---------|-----|
| `"error"` | yes | yes | Like `--include` |
| `"warn"` | yes (faded) | no | Visible but non-blocking |
| `"off"` | no | no | Like `--exclude` |

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success, no issues |
| `1` | Success, issues found |
| `2` | Internal error or bad input |

## Common Workflows

```bash
knip
knip --include files,dependencies
knip --exports
knip --production --strict
knip --fix
knip --fix --allow-remove-files --format
knip --fix-type exports,types
knip --reporter json
knip --debug
knip --trace-export myFunction
knip --trace-dependency react
knip --watch
knip --cache
knip --max-show-issues 5
```

## Post-fix Checklist

1. Run formatter (or use `--format` flag)
2. Run ESLint/Biome to remove unused variables left behind
3. Run `npm install` / `pnpm install` to update lockfile after dependency removal
4. Run knip again — removing code may reveal more unused code
