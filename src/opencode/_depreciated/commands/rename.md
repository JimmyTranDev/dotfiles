---
name: rename
description: Rename a symbol across the entire codebase with verification
---

Usage: /rename [old-name] [new-name]

Rename a symbol (variable, function, class, file, etc.) across the entire codebase and verify nothing breaks.

$ARGUMENTS

1. If old-name or new-name is not provided, notify the user and stop
2. Search the entire codebase for all occurrences of old-name using grep
3. If no occurrences are found, notify the user and stop
4. Display a preview showing all files and lines that will change, grouped by file
5. Ask the user for confirmation before proceeding
6. Perform the rename:
   - Replace all occurrences in file contents
   - If old-name matches a filename, rename the file as well
   - Update import paths if file was renamed
7. Run the build command (if available) to verify no breakage
8. Run the lint command (if available) to verify no style issues
9. If build or lint fails:
   - Revert all changes: `git checkout -- .`
   - Report the failure with error output
   - Suggest what might need manual attention
10. If everything passes, report the total number of replacements across files

Constraints:
- Always show a preview and get confirmation before making changes
- Use word-boundary-aware matching to avoid partial replacements (e.g., renaming `user` should not affect `username` unless explicitly requested)
- If the old-name appears in generated files (node_modules, dist, build), skip those
- Revert on any verification failure — never leave the codebase in a broken state
