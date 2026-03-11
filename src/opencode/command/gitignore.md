---
name: gitignore
description: Optimize the .gitignore for the current project based on its tech stack and tracked files
---

Usage: /gitignore

Analyze the current project and create or optimize its `.gitignore` to follow best practices for the detected tech stack.

1. **Detect the tech stack** by scanning the repo root for manifest files:

   | File | Stack |
   |------|-------|
   | `package.json` | Node.js / JavaScript / TypeScript |
   | `tsconfig.json` | TypeScript |
   | `Cargo.toml` | Rust |
   | `go.mod` | Go |
   | `pyproject.toml`, `requirements.txt`, `setup.py` | Python |
   | `Gemfile` | Ruby |
   | `pom.xml`, `build.gradle` | Java / Kotlin |
   | `*.sln`, `*.csproj` | .NET / C# |
   | `Package.swift` | Swift |
   | `pubspec.yaml` | Dart / Flutter |
   | `docker-compose.yml`, `Dockerfile` | Docker |
   | `ios/`, `android/` | React Native / Mobile |

   Also check for frameworks: Next.js (`next.config.*`), Expo (`app.json` with expo), Vite (`vite.config.*`), etc.

2. **Read the existing `.gitignore`** if one exists:
   - Parse each entry and categorize it (OS, IDE, language, framework, build output, secrets, custom)
   - Identify any entries that are misspelled, redundant, or no longer relevant
   - Note any tracked files that should be ignored (run `git ls-files` to cross-reference)

3. **Check for files that should be ignored but aren't**:
   - Run `git status --porcelain` to find untracked files
   - Run `git ls-files` to find tracked files that match common ignore patterns
   - Flag tracked files that are typically ignored (e.g., `.env`, `dist/`, `node_modules/`, `.DS_Store`)

4. **Build the optimized `.gitignore`** organized by category:

   ```
   # OS
   .DS_Store
   Thumbs.db

   # IDE
   .idea/
   .vscode/
   *.swp

   # Dependencies
   node_modules/

   # Build output
   dist/
   build/

   # Environment
   .env
   .env.*
   !.env.example

   # Secrets
   credentials.json

   # Logs
   *.log

   # Framework-specific
   .next/
   .expo/
   ```

   Rules:
   - Group entries under category headers
   - Sort entries alphabetically within each category
   - Use directory trailing slash for directories (`node_modules/` not `node_modules`)
   - Use negation patterns (`!`) to preserve example/template files
   - Remove duplicate or redundant patterns (e.g., `dist` when `dist/` exists)
   - Remove entries for tools the project doesn't use

5. **Present the changes to the user**:
   - If creating a new file: show the full proposed `.gitignore`
   - If updating: show a diff of what will change (additions, removals, reorderings)
   - If tracked files need untracking: list them and suggest `git rm --cached <file>`
   - Ask for confirmation before writing

6. **Write the file** after user confirms

Important:
- Never remove custom project-specific entries the user has added unless they are clearly wrong
- Always preserve negation patterns (`!.env.example`) — these are intentional
- If the project has a monorepo structure, check for `.gitignore` files in sub-packages too
- Do not add entries for tools not detected in the project — keep it minimal and relevant
- Comment headers are allowed in `.gitignore` files despite the no-comments policy — they are standard practice for organization
