---
name: git-gitignore
description: Tech stack detection, .gitignore organization by category, pattern rules, and tracked file cross-referencing for optimizing .gitignore files
---

Optimize `.gitignore` files based on detected tech stack, organized by category with consistent rules.

## Tech Stack Detection

Detect the stack by scanning the repo root for manifest files:

| File | Stack |
|------|-------|
| `package.json` | Node.js / JavaScript / TypeScript |
| `tsconfig.json` | TypeScript |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pyproject.toml`, `requirements.txt`, `setup.py` | Python |
| `Gemfile` | Ruby |
| `pom.xml`, `build.gradle`, `build.gradle.kts` | Java / Kotlin |
| `*.sln`, `*.csproj` | .NET / C# |
| `Package.swift` | Swift |
| `pubspec.yaml` | Dart / Flutter |
| `docker-compose.yml`, `Dockerfile` | Docker |
| `ios/`, `android/` | React Native / Mobile |

### Framework Detection

| File | Framework |
|------|-----------|
| `next.config.*` | Next.js |
| `nuxt.config.*` | Nuxt |
| `vite.config.*` | Vite |
| `app.json` (with `expo` key) | Expo |
| `angular.json` | Angular |
| `svelte.config.*` | SvelteKit |
| `remix.config.*` | Remix |
| `astro.config.*` | Astro |
| `tailwind.config.*` | Tailwind CSS |
| `turbo.json` | Turborepo |

## Category Organization

Organize entries under category headers in this order:

```gitignore
# OS
.DS_Store
Thumbs.db
Desktop.ini

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# Dependencies
node_modules/
vendor/
.pnpm-store/

# Build output
dist/
build/
out/
.next/
.nuxt/
.expo/
target/

# Environment
.env
.env.*
!.env.example

# Secrets
credentials.json
*.pem
*.key

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Testing
coverage/
.nyc_output/

# Framework-specific
# (entries specific to the detected framework)
```

## Stack-Specific Patterns

### Node.js / TypeScript
```gitignore
node_modules/
dist/
build/
*.tsbuildinfo
.eslintcache
```

### Rust
```gitignore
target/
Cargo.lock  # only for libraries, not binaries
```

### Go
```gitignore
bin/
*.exe
```

### Python
```gitignore
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
.mypy_cache/
.pytest_cache/
```

### Java / Kotlin
```gitignore
target/
build/
*.class
*.jar
*.war
.gradle/
```

### .NET
```gitignore
bin/
obj/
*.user
*.suo
```

### Dart / Flutter
```gitignore
.dart_tool/
.packages
build/
*.iml
```

### React Native / Expo
```gitignore
ios/Pods/
ios/build/
android/build/
android/app/build/
.expo/
```

## Pattern Rules

| Rule | Example |
|------|---------|
| Trailing slash for directories | `node_modules/` not `node_modules` |
| Negation to preserve templates | `!.env.example` after `.env.*` |
| Alphabetical within categories | `build/` before `dist/` |
| No entries for unused tools | Don't add `.idea/` if no one uses IntelliJ |
| No duplicate patterns | Remove `dist` when `dist/` exists |
| Glob for file extensions | `*.log` not individual log filenames |

## Cross-Referencing Tracked Files

Commands to detect mismatches:

| Purpose | Command |
|---------|---------|
| Find tracked files that should be ignored | `git ls-files` and compare against ignore patterns |
| Find untracked files that might need ignoring | `git status --porcelain` |
| Untrack a file without deleting it | `git rm --cached <file>` |
| Untrack a directory without deleting it | `git rm -r --cached <dir>/` |

## Rules

- Never remove custom project-specific entries unless clearly wrong
- Always preserve negation patterns (`!.env.example`) — they are intentional
- In monorepos, check for `.gitignore` files in sub-packages
- Only add entries for tools actually detected in the project — keep it minimal
- Category comment headers are standard practice in `.gitignore` files
