---
name: merge-specs
description: Merge multiple spec files into a single consolidated specification
---

Usage: /merge-specs [$ARGUMENTS]

Merge multiple spec files from `spec/` into a single consolidated spec.

1. List available spec files:
   - Run `ls spec/*.md` to find all spec files
   - If `$ARGUMENTS` specifies filenames, use those
   - If no arguments, present all spec files via the question tool with multi-select enabled
   - If only one spec file exists, warn and exit — nothing to merge

2. Read all selected spec files

3. Merge the contents:
   - Combine findings from all specs, grouping by category
   - Deduplicate identical or near-identical findings
   - Preserve severity rankings — if the same issue appears in multiple specs with different severities, keep the highest
   - Create a merged overview section summarizing all source specs

4. Write the merged spec:
   - Ask the user for a name, or derive from the source filenames
   - Write to `spec/<merged-name>.md`
   - If the filename already exists, append a numeric suffix

5. Optionally delete originals:
   - Ask the user if they want to delete the source spec files
   - If yes, delete them

6. Report:
   - Path to the merged spec
   - Number of findings merged
   - Number of duplicates removed
