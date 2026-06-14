---
name: tool-turborepo
description: Turborepo patterns covering pipeline config, caching, filtering, workspace dependencies, and monorepo task orchestration
---

## Project Structure

```
monorepo/
├── turbo.json              # Pipeline configuration
├── package.json            # Root workspace config
├── apps/
│   ├── web/               # Next.js app
│   ├── api/               # Backend service
│   └── mobile/            # React Native app
└── packages/
    ├── ui/                # Shared component library
    ├── config-eslint/     # Shared ESLint config
    ├── config-typescript/ # Shared tsconfig
    └── shared/            # Shared utilities/types
```

## turbo.json Configuration

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "globalEnv": ["NODE_ENV"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"],
      "env": ["DATABASE_URL"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["build"],
      "inputs": ["src/**", "test/**"]
    },
    "typecheck": {
      "dependsOn": ["^build"]
    },
    "clean": {
      "cache": false
    }
  }
}
```

## Task Configuration Options

| Field | Purpose |
|-------|---------|
| `dependsOn` | Tasks that must complete first |
| `^dependsOn` | Same task in dependency packages first |
| `outputs` | Files to cache (glob patterns) |
| `inputs` | Files that affect cache key (default: all tracked by git) |
| `cache` | Enable/disable caching (default: true) |
| `persistent` | Long-running process (dev servers) |
| `env` | Environment variables that affect cache key |
| `passThroughEnv` | Env vars passed through without affecting cache |
| `outputLogs` | `full` \| `hash-only` \| `new-only` \| `errors-only` \| `none` |
| `interactive` | Task requires stdin |

## Dependency Syntax

| Syntax | Meaning |
|--------|---------|
| `"^build"` | Run `build` in all dependency packages first |
| `"build"` | Run `build` in same package first |
| `"web#build"` | Run `build` in specific `web` package first |
| `"//#build"` | Run `build` in root package first |

## CLI Commands

### Running Tasks
```bash
turbo run build
turbo run build lint test          # Multiple tasks
turbo run build --parallel         # Ignore task ordering
turbo run dev --concurrency=5      # Limit parallel tasks
turbo run build --continue         # Continue on errors
turbo run build --dry              # Show what would run
turbo run build --graph            # Generate task graph
```

### Filtering
```bash
turbo run build --filter=web              # Single package
turbo run build --filter=web...           # Package + dependencies
turbo run build --filter=...web           # Package + dependents
turbo run build --filter='./apps/*'       # Directory glob
turbo run build --filter='[HEAD~1]'       # Changed since commit
turbo run build --filter=web...[main]     # Changed in web since main
turbo run build --filter=!web             # Exclude package
```

### Cache Management
```bash
turbo run build --force            # Bypass cache
turbo run build --no-cache         # Don't write cache
turbo run build --summarize        # Show cache hit/miss summary
turbo prune web                    # Create sparse monorepo for deployment
```

## Workspace Dependencies

### Package.json Internal Dependencies
```json
{
  "dependencies": {
    "@repo/ui": "workspace:*",
    "@repo/shared": "workspace:*"
  }
}
```

### Dependency Rules (turbo.json)
```json
{
  "tasks": {
    "web#build": {
      "dependsOn": ["ui#build", "shared#build"]
    }
  }
}
```

## Caching

### What Gets Cached
- Task outputs (files matching `outputs` glob)
- Terminal output logs
- Keyed by: inputs hash + env vars + dependencies hash + task config

### Cache Locations
- Local: `node_modules/.cache/turbo`
- Remote: Vercel Remote Cache or custom server

### Remote Cache Setup
```bash
turbo login                        # Authenticate with Vercel
turbo link                         # Link repo to Vercel team
```

### Custom Remote Cache
```json
{
  "remoteCache": {
    "enabled": true,
    "signature": true
  }
}
```

## turbo prune (Deployment)

```bash
turbo prune web --docker
```

Generates:
```
out/
├── json/                  # Package.json files only (for install layer)
│   ├── package.json
│   └── packages/ui/package.json
├── full/                  # Full source (for build layer)
└── pnpm-lock.yaml         # Pruned lockfile
```

### Dockerfile Pattern
```dockerfile
FROM node:20-alpine AS base

FROM base AS installer
WORKDIR /app
COPY out/json/ .
RUN pnpm install --frozen-lockfile

FROM base AS builder
WORKDIR /app
COPY out/full/ .
COPY --from=installer /app/node_modules ./node_modules
RUN pnpm turbo run build --filter=web

FROM base AS runner
WORKDIR /app
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder /app/apps/web/.next/static ./apps/web/.next/static
CMD ["node", "apps/web/server.js"]
```

## Workspace Configuration

### Root package.json (pnpm)
```json
{
  "private": true,
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "lint": "turbo run lint",
    "test": "turbo run test",
    "typecheck": "turbo run typecheck",
    "clean": "turbo run clean && rm -rf node_modules"
  },
  "devDependencies": {
    "turbo": "^2"
  },
  "packageManager": "pnpm@9.0.0"
}
```

### pnpm-workspace.yaml
```yaml
packages:
  - "apps/*"
  - "packages/*"
```

## Common Patterns

### Shared TypeScript Config
```json
// packages/config-typescript/base.json
{
  "compilerOptions": {
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noUncheckedIndexedAccess": true
  }
}
```

### Package Exports
```json
{
  "name": "@repo/ui",
  "exports": {
    ".": "./src/index.ts",
    "./button": "./src/button.tsx"
  },
  "typesVersions": {
    "*": { "*": ["src/*"] }
  }
}
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Missing `^` in dependsOn | Add `^` to run deps first |
| Dev task cached | Set `"cache": false` |
| Outputs not restored from cache | Check `outputs` glob patterns |
| Env var changes not busting cache | Add to `env` or `globalEnv` |
| Slow CI due to no remote cache | Enable Vercel Remote Cache |
| `turbo prune` missing packages | Check workspace dependency declarations |
| Tasks running in wrong order | Use `--dry` to debug task graph |
| Lockfile changes busting all caches | Use `inputs` to scope cache keys |
