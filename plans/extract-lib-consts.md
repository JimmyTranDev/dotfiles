# Extract lib/ constants into consts/ folder

## TL;DR

- Extract 16 constants (6 colors, 9 emojis, 1 array) from `logging.sh` and `utility.sh` into `etc/scripts/consts/`
- 2 new files: `consts/colors.sh`, `consts/emoji.sh`, `consts/dirs.sh`
- Update `logging.sh` and `utility.sh` to source from `consts/`
- No external reference changes needed — consumers source `logging.sh`/`utility.sh` which re-export
- Estimated effort: small

## Overview

Constants in `logging.sh` (color codes, emoji) and `utility.sh` (`PROGRAMMING_EXCLUDED_DIRS`) are currently mixed with function definitions. Extracting them into dedicated `consts/*.sh` files improves discoverability and allows scripts to source only constants without pulling in functions.

## Architecture

```
etc/scripts/
├── consts/
│   ├── colors.sh              # RED, GREEN, BLUE, YELLOW, CYAN, NC
│   ├── emoji.sh               # EMOJI_SUCCESS, EMOJI_ERROR, etc.
│   └── dirs.sh                # PROGRAMMING_EXCLUDED_DIRS
├── lib/
│   ├── logging.sh             # sources consts/colors.sh + consts/emoji.sh
│   ├── utility.sh             # sources consts/dirs.sh
│   └── ...
```

Existing scripts that `source lib/logging.sh` get constants transitively — no changes needed in `src/` scripts.

## Tasks

### 1. Create `consts/colors.sh`
- **Path**: `etc/scripts/consts/colors.sh`
- **Action**: New file with `RED`, `GREEN`, `BLUE`, `YELLOW`, `CYAN`, `NC`
- **Complexity**: small
- **Parallel**: yes (with tasks 2, 3)

### 2. Create `consts/emoji.sh`
- **Path**: `etc/scripts/consts/emoji.sh`
- **Action**: New file with all `EMOJI_*` constants
- **Complexity**: small
- **Parallel**: yes (with tasks 1, 3)

### 3. Create `consts/dirs.sh`
- **Path**: `etc/scripts/consts/dirs.sh`
- **Action**: New file with `PROGRAMMING_EXCLUDED_DIRS`
- **Complexity**: small
- **Parallel**: yes (with tasks 1, 2)

### 4. Update `lib/logging.sh`
- **Path**: `etc/scripts/lib/logging.sh`
- **Action**: Remove inline constants, add `source` of `consts/colors.sh` and `consts/emoji.sh` using `SCRIPT_DIR` relative path
- **Depends on**: tasks 1, 2
- **Complexity**: small

### 5. Update `lib/utility.sh`
- **Path**: `etc/scripts/lib/utility.sh`
- **Action**: Remove `PROGRAMMING_EXCLUDED_DIRS` inline, add `source` of `consts/dirs.sh`
- **Depends on**: task 3
- **Complexity**: small

### 6. Update `AGENTS.md` (root)
- **Path**: `AGENTS.md`
- **Action**: Add `consts/` to the `etc/scripts/` directory tree
- **Complexity**: small

### 7. Update `src/opencode/AGENTS.md`
- **Path**: `src/opencode/AGENTS.md`
- **Action**: Note `consts/` as shared constants directory if referenced
- **Complexity**: small

## Edge cases

- `worktree_core.sh` (zsh) sources `utility.sh` which will transitively source `consts/dirs.sh` — bash `source` in zsh context works fine since these are just variable assignments
- Guard pattern (`[[ -n "${_CONSTS_X_LOADED:-}" ]] && return 0`) should be added to each consts file to prevent double-loading

## Testing approach

- Run `bash -n` on all new and modified files
- Run `source lib/logging.sh && echo $RED` to verify transitive loading
- Run `source lib/utility.sh && echo ${PROGRAMMING_EXCLUDED_DIRS[@]}` to verify
- Grep for any direct references to the moved constants to ensure nothing breaks

## Open questions

None — scope is clear and self-contained.
