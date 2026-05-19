---
name: scan-style
description: Scan a codebase to detect coding conventions and generate a skill file capturing the project's style
---

Usage: /scan-style [directory] [--name skill-name] [--output path]

$ARGUMENTS

Analyze the target codebase and generate a skill file that captures its coding conventions for future use by the `code-follower` skill.

## Workflow

1. Load the **code-follower** and **code-conventions** skills in parallel for reference

2. Determine scope:
   - If `$ARGUMENTS` specifies a directory, use that
   - Otherwise, use the current workspace root

3. Run `scan-style.sh [directory]` to gather file statistics, naming patterns, config file list, and sample file paths

4. Determine the skill name:
   - If `--name` is provided, use it
   - Otherwise, derive from the project directory name (kebab-case)

5. Read config files detected by the script (eslint, prettier, tsconfig, biome, editorconfig) to extract explicit rules

6. Use the **explore** agent to sample 5-10 representative files per major file type and analyze:
   - **Naming**: variable/function casing, file naming, component naming, constant naming
   - **Imports**: ordering (external vs internal), grouping, path aliases, barrel files
   - **File structure**: feature-based vs type-based, index files, co-location patterns
   - **Components** (if React/RN): props pattern, export style, hook ordering, JSX patterns
   - **Error handling**: try-catch vs result types, error logging, error boundaries
   - **TypeScript**: type vs interface, generics usage, strict null handling, utility types
   - **State management**: local state patterns, global store approach, data fetching
   - **Testing**: test structure, mock patterns, assertion style, file naming
   - **Formatting**: indentation, quotes, semicolons, trailing commas, line length

7. Check if the output skill file already exists:
   - Default location: `.opencode/skills/<skill-name>/SKILL.md` (project-local)
   - If `--output` is provided, use that path instead
   - If the file exists, ask the user: "A skill file already exists at this path. Overwrite?"

8. Create the skill directory if needed and write the skill file:

```markdown
---
name: <skill-name>-conventions
description: Code style conventions detected from <project-name> — covers naming, imports, structure, error handling, and TypeScript patterns
---

# <Project Name> Conventions

Detected on <date> from <file-count> source files.

## Naming

### Files
<detected pattern with examples>

### Variables and Functions
<detected pattern with examples>

### Components
<detected pattern with examples>

### Constants and Enums
<detected pattern with examples>

## Imports

### Ordering
<detected order with example>

### Path Aliases
<detected aliases>

### Barrel Files
<usage pattern>

## File Structure

<detected organization pattern — feature-based, type-based, or hybrid>

## Components

<props pattern, export style, hook ordering>

## Error Handling

<detected pattern with examples>

## TypeScript Patterns

<type vs interface preference, generics, strict null, utility types>

## State Management

<local state, global store, data fetching patterns>

## Testing

<test structure, naming, mocking, assertions>

## Formatting (from config)

<indentation, quotes, semicolons, line length from config files>
```

9. Report the generated skill file path and a summary of detected conventions

## Rules

- Do NOT modify any source code — this command is read-only (except for the generated skill file)
- Include concrete examples from the actual codebase in each section (2-3 per category)
- If a category has no clear convention (inconsistent across files), note it as "Mixed — no dominant pattern"
- Omit sections that don't apply (e.g., no "Components" section for a pure backend project)
- Keep the skill file actionable — patterns and examples, not prose explanations
