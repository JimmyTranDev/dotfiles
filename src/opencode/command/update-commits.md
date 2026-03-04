---
name: update-commits
description: Update all commits in current branch with conventional commit format and emoji prefixes
---

Search for all commits with the text "update". Update them to have a better description while follow conventional commit format with emoji prefixes:

- Review the commit history from the current branch back to main/master
- For each commit, analyze the changes and rewrite the commit message with:
  - An emoji prefix matching the type of change (✨ feat, 🐛 fix, 📚 docs, 🔨 refactor, 💎 style, 🧪 test, 🚀 perf, 🔧 chore, etc.)
  - Clear, concise commit message following conventional commits format: `type(scope): description`
  - Preserve the original commit content and authorship
- Use `git rebase` with `GIT_SEQUENCE_EDITOR` to non-interactively change `pick` to `reword` for target commits, then use `GIT_EDITOR` with a script to set the new message for each commit

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

Analyze each commit's diff to determine the most appropriate type and scope.
