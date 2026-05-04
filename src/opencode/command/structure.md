---
name: structure
description: Analyze project directory layout and file placement using the meta-structure skill
---

Usage: /structure [scope or description]

$ARGUMENTS

1. Load the **meta-structure** skill

**Scope**

2. If `$ARGUMENTS` specifies a file path, focus on the containing folder and all its contents
3. If `$ARGUMENTS` specifies a directory, focus on that folder and all its contents — if the directory contains nested feature folders (each with their own `index.tsx`), process each feature folder independently using parallel agents (one agent per feature folder)
4. If no arguments provided, analyze the entire `src/` directory

**Analysis**

5. Analyze the current project's directory structure against the skill's recommended layout
6. Identify misplaced files, missing directories, and organizational improvements
7. Present findings as a prioritized list of structural improvements with specific file moves or directory creations

**Transformation**

8. Read every `index.tsx`, `index.ts`, and flat `.ts` files in scope and extract into separate files at the appropriate level (feature root or sub-component folder), even if they are short:
   - Constants → `consts.ts`
   - Utility/helper functions → `utils.ts`
   - Types and interfaces → `types.ts`
   - Non-trivial logic (data fetching, state management, side effects) → custom hooks in `hooks.ts`
9. If a target file (`consts.ts`, `utils.ts`, `types.ts`, `hooks.ts`) already exists, merge into it rather than overwriting
10. Prefer named function declarations with a default export (e.g., `export default function MyComponent() {}`) over anonymous arrow-function exports
11. Before placing any extracted sub-component, grep for all importers across the codebase. If only ONE parent imports it, nest it inside that parent's folder (not at feature root). If multiple parents import it, place at feature root as a sibling folder. Always default to nesting — only promote to feature root when sharing is proven.
12. Extract inline JSX into new sub-component folders when a distinct UI section is identifiable (e.g., a list item, a header, a card) — even if it's only rendered once
13. For flat files (e.g., `useSync.ts`, `useStore.ts`), convert each to a folder (`useSync/index.ts`) with extracted `types.ts`, `consts.ts`, `utils.ts` as appropriate — even if the file is small
14. When converting a flat `.ts` file to a directory with `index.ts`, TypeScript module resolution auto-resolves `import from './useStore'` to `./useStore/index.ts` — imports using **path aliases** (e.g., `~/lib/stores/useStore`) need NO updates. Only **relative imports** that gain nesting depth need fixing.
15. If the scoped directory lacks a barrel `index.ts`, create one with re-exports of all public modules

**Execution**

16. Apply the changes — move files, create directories, and update imports as needed
17. Update re-exports in any `index.ts` barrel files affected by moves
18. When extracting types/interfaces to `types.ts`, ensure they are **re-exported from `index.ts`** if other modules import them from the parent path (e.g., `export type { UseThrottledRefreshOptions } from './types'`)
19. When moving a file one directory deeper (e.g., `hooks/useX.ts` → `hooks/useX/index.ts`), fix all **relative paths** like `require('../../../foo')` → `require('../../../../foo')` — add one extra `../` per nesting level added. Path-alias imports (`~/...`) are unaffected.
20. After all changes, run the formatter (prettier) on new/modified files, then `eslint --fix` on the affected directory to auto-fix import ordering issues
21. Verify the project still builds/compiles after structural changes (`lint` + `tsc --noEmit` + tests)
