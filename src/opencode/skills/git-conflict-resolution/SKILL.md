---
name: git-conflict-resolution
description: Git merge conflict patterns, conflict marker anatomy, resolution strategies, rebase vs merge decisions, file-type-specific resolution, and post-resolution verification
---

Resolve git merge conflicts correctly by understanding both sides, choosing the right strategy, and verifying the result.

## Conflict Marker Anatomy

### Standard Merge (diff2)

```
<<<<<<< HEAD (ours)
  current branch code
=======
  incoming branch code
>>>>>>> feature-branch (theirs)
```

### Three-Way Merge (diff3)

```
<<<<<<< HEAD (ours)
  current branch code
||||||| merged common ancestor
  original code before either change
=======
  incoming branch code
>>>>>>> feature-branch (theirs)
```

diff3 shows the common ancestor, making it clear what each side changed relative to the original. Prefer diff3 — it's configured globally via `merge.conflictstyle = diff3`.

## Resolution Decision Tree

```
Read both sides of the conflict:
├─ Only one side made a meaningful change?
│  └─ Keep the changed side, discard the unchanged side
├─ Both sides changed the same thing differently?
│  ├─ Changes are logically compatible?
│  │  └─ Combine both changes into a merged result
│  └─ Changes are mutually exclusive?
│     └─ Ask the user which to keep — never silently drop code
├─ Both sides added new code (no overlap)?
│  └─ Keep both additions in logical order
├─ One side deleted code the other side modified?
│  ├─ Deletion was intentional cleanup?
│  │  └─ Keep the deletion, discard the modification
│  └─ Modification is still needed?
│     └─ Keep the modification
└─ Conflict is in generated or lock files?
   └─ Regenerate the file instead of manual resolution
```

## Resolution Strategies by Conflict Type

### Import / Dependency Conflicts

| Scenario | Resolution |
|----------|------------|
| Both sides added different imports | Keep both, sort alphabetically |
| One side removed an import the other still uses | Keep the import if it's still referenced |
| Both sides upgraded the same dependency to different versions | Use the higher version, check compatibility |
| Lock file conflict (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`) | Do not manually edit — regenerate with the package manager |

### Function / Logic Conflicts

| Scenario | Resolution |
|----------|------------|
| Both sides modified the same function body | Understand the intent of each change, merge logic manually |
| One side renamed a function the other side modified | Apply the rename and the modification |
| Both sides added parameters to the same function | Combine parameters, update all call sites |
| One side refactored, other side added features | Apply features on top of the refactored structure |

### Configuration Conflicts

| Scenario | Resolution |
|----------|------------|
| Both sides added different config keys | Keep both keys |
| Both sides changed the same config value | Determine which value is correct for the target branch |
| One side restructured config format | Apply the restructure, then apply the other side's value changes |

### Style / Formatting Conflicts

| Scenario | Resolution |
|----------|------------|
| Whitespace-only differences | Accept either side, then run the formatter |
| Line ending differences | Accept either side, ensure `.gitattributes` enforces consistency |
| Both sides reformatted the same code | Accept either side — result is identical after formatting |

## File-Type-Specific Resolution

### Generated Files — Never Manually Resolve

| File | Resolution |
|------|------------|
| `package-lock.json` | `npm install` |
| `yarn.lock` | `yarn install` |
| `pnpm-lock.yaml` | `pnpm install` |
| `*.min.js`, `*.min.css` | Rebuild from source |
| `*.generated.ts` | Re-run the generator |
| Binary files (images, fonts) | Choose one version explicitly |

### Schema / Migration Files

- Never merge two migrations into one — keep both in order
- If both sides added a migration with the same sequence number, renumber the later one
- Schema files should reflect the result of all migrations applied

### Test Files

- Keep all tests from both sides
- If both sides modified the same test, merge the assertions
- Run the test suite after resolution to verify

## Rebase vs Merge Decision

| Use Rebase When | Use Merge When |
|-----------------|----------------|
| Updating a feature branch with base branch changes | Integrating a completed feature into the base branch |
| Branch has not been pushed or is not shared | Branch has been pushed and others may have based work on it |
| You want a linear commit history | You want to preserve the branch topology |
| Conflicts are minimal and straightforward | Conflicts are complex and you want a single merge commit to track resolution |

### Rebase Conflict Resolution

- Conflicts appear commit-by-commit during rebase
- Resolve each commit's conflicts, then `git rebase --continue`
- If a commit becomes empty after resolution, `git rebase --skip`
- To abort a rebase gone wrong: `git rebase --abort`
- After rebase, force push is required: `git push --force-with-lease` (never `--force`)

### Merge Conflict Resolution

- All conflicts appear at once after `git merge`
- Resolve all conflicted files, stage them, then `git commit`
- To abort: `git merge --abort`
- No force push needed after merge

## Common Pitfalls

| Pitfall | Prevention |
|---------|------------|
| Silently dropping one side's changes | Always read both sides and the ancestor (diff3) before resolving |
| Manually editing lock files | Regenerate instead — manual edits cause inconsistencies |
| Resolving without understanding context | Read the commits that introduced each side's changes (`git log --merge`) |
| Forgetting to stage resolved files | `git add` each file after resolving, or use `git add .` when all are done |
| Not testing after resolution | Always run build + tests after resolving all conflicts |
| Force pushing after rebase on shared branch | Use `--force-with-lease` and verify no one else pushed |
| Accepting "ours" or "theirs" blindly | Only use `-X ours` or `-X theirs` when you've verified one side is entirely correct |

## Useful Commands

| Command | Purpose |
|---------|---------|
| `git diff --name-only --diff-filter=U` | List all conflicted files |
| `git log --merge --oneline` | Show commits involved in the conflict |
| `git log --merge -p -- <file>` | Show the commits that conflict for a specific file |
| `git diff --base <file>` | Show changes from common ancestor to working tree |
| `git diff --ours <file>` | Show what our side changed |
| `git diff --theirs <file>` | Show what their side changed |
| `git checkout --ours <file>` | Accept our version entirely |
| `git checkout --theirs <file>` | Accept their version entirely |
| `git merge --abort` | Abort the merge and return to pre-merge state |
| `git rebase --abort` | Abort the rebase and return to pre-rebase state |
| `git rebase --continue` | Continue rebase after resolving a commit's conflicts |
| `git push --force-with-lease` | Safe force push after rebase (rejects if remote has new commits) |

## Post-Resolution Verification

1. **Check no markers remain** — search for `<<<<<<<`, `=======`, `>>>>>>>` in resolved files
2. **Run the build** — compile errors reveal missing imports or broken references
3. **Run tests** — failing tests reveal dropped logic or incorrect merges
4. **Run linter/formatter** — ensures merged code matches project style
5. **Review the diff** — `git diff <base-branch>...HEAD` to verify the full change set makes sense
6. **Check import integrity** — ensure no dangling imports from deleted or moved code

## What This Skill Does NOT Cover

- Branch naming and commit message conventions — see **git-workflows** skill
- Worktree lifecycle and management — see **worktree-workflow** skill
