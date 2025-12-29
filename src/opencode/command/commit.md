---
name: commit
description: Create a well-formatted git commit with emoji prefix and conventional format
---

Review my staged changes and create a well-formatted git commit with:
- An emoji prefix matching the type of change (✨ feat, 🐛 fix, 📚 docs, 🔨 refactor, 💎 style, 🧪 test, 🚀 perf, 🔧 chore, etc.)
- A clear, concise commit message following conventional commits format

Common emoji mappings:
- ✨ feat: new features
- 🐛 fix: bug fixes
- 📚 docs: documentation changes
- 🔨 refactor: code refactoring
- 💎 style: formatting, styling
- 🧪 test: adding/updating tests
- 🚀 perf: performance improvements
- 🔧 chore: maintenance tasks
- 👷 ci: CI/CD changes
- 📦 build: build system changes
- ⏪ revert: reverting changes

Important: When staging files for commit, ignore any files with `-actx` suffix (these are temporary symlinks).

Analyze the git diff to understand the changes, then create the commit.
