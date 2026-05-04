---
name: changelog
description: Generate changelog entries from git history between two refs
---

Usage: /changelog [from-ref] [to-ref]

Generate a structured changelog in Keep a Changelog format by analyzing git commits between two references.

$ARGUMENTS

1. Determine the ref range:
   - If from-ref is not provided, default to the most recent git tag (`git describe --tags --abbrev=0`)
   - If to-ref is not provided, default to HEAD
   - If no tags exist and no from-ref is given, notify the user and stop
2. Run `git log --oneline --no-merges <from-ref>..<to-ref>` to collect all commits
3. Categorize each commit by its conventional commit prefix:
   - `feat` → Added
   - `fix` → Fixed
   - `refactor` → Changed
   - `perf` → Changed (Performance)
   - `docs` → Documentation
   - `test` → Tests
   - `chore` / `build` / `ci` → Maintenance
   - No prefix → Other
4. Group commits by category
5. Within each category, list entries as bullet points with the commit message (without the prefix)
6. Output the changelog in Keep a Changelog format:
   ```
   ## [Unreleased] - YYYY-MM-DD

   ### Added
   - ...

   ### Fixed
   - ...
   ```
7. Print the changelog to chat — do not write to a file unless the user requests it

Constraints:
- Do not modify any files unless explicitly asked
- If the ref range produces zero commits, notify the user that there are no changes between the refs
- Exclude merge commits from the output
