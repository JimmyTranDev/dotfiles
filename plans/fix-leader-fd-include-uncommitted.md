# Fix: `<leader>fd` should include uncommitted changes

## Overview

The `<leader>fd` keybinding uses `Snacks.picker.git_diff({ base = base })` which internally passes `--merge-base <base>` to git. This has two problems: (1) it excludes uncommitted/staged changes from the results, and (2) it can fail with "Command failed" when `--merge-base` cannot compute a merge base (e.g., on the base branch itself). The fix is to pass the base ref via `args` instead of `base`, so Snacks runs its default dual-finder (staged + unstaged) behavior while still diffing against the target branch.

## Architecture

**File:** `~/Programming/JimmyTranDev/nvim/lua/plugins/snacks.lua` lines 414-428

The current code:
```lua
Snacks.picker.git_diff({ base = base })
```

When `base` is set, Snacks:
- Adds `--merge-base <base>` to the git diff command
- Skips the staged changes finder entirely
- Disables stage/unstage/restore actions

When `base` is **not** set but `args` contains the ref, Snacks:
- Runs two finders: unstaged diff + staged diff (`--cached`)
- Keeps stage/unstage/restore actions enabled
- The ref in `args` makes git diff against that ref instead of HEAD

## Tasks

### 1. Change `git_diff` call to use `args` instead of `base`

- **File:** `lua/plugins/snacks.lua` line 425
- **Change:** Replace `Snacks.picker.git_diff({ base = base })` with `Snacks.picker.git_diff({ args = { base } })`
- **Effect:** `git diff <base>` shows all differences between working tree and the base branch (committed + uncommitted). The staged finder also runs with `git diff --cached <base>`, capturing staged changes too.
- **Complexity:** small
- **Parallel:** standalone

### 2. Verify behavior on the base branch itself

- **After fix:** When on `main` and base is `main`, `git diff main` produces no output (correct — no changes). No `--merge-base` error.
- **Complexity:** small (manual verification)

## Edge Cases

- **On the base branch with no changes:** Should show empty picker (no error)
- **On the base branch with uncommitted changes:** Should show those changes
- **On a feature branch with uncommitted changes:** Should show both committed branch diff AND uncommitted changes
- **Detached HEAD:** `git diff main` still works; no merge-base computation needed

## Testing Approach

Manual verification:
1. Check out `main`, make an uncommitted change, press `<leader>fd` — should show the change
2. Check out a feature branch with commits ahead of main, make an uncommitted change, press `<leader>fd` — should show both committed diff and uncommitted change
3. Check out `main` with no changes, press `<leader>fd` — should show empty picker, no error

## Open Questions

None — the fix is straightforward.
