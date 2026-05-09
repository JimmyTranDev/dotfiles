# Restructure etc/scripts/ into lib/ + src/

## TL;DR

- Rename `common/` to `lib/` and merge `worktrees/lib/` (core.sh, jira.sh) into it
- Move all entry-point scripts into `src/` grouped by category: `src/worktrees/`, `src/ai/`, `src/install/`, `src/system/`, `src/dev/`, `src/terminal/`
- Update ~35 source/reference paths across .zshrc, AGENTS.md, skill files, and internal script imports
- 17 tasks total, estimated medium effort (mostly mechanical path updates, but high blast radius)
- Critical risk: broken aliases and source paths if any reference is missed

## Overview

The current `etc/scripts/` layout mixes shared libraries (`common/`), entry-point scripts (loose `.sh` files), and tool-specific directories (`ai/`, `worktrees/`, `install/`). This restructure creates a clean separation: `lib/` for shared sourced libraries and `src/` for grouped entry-point scripts. The `worktrees/lib/` files (core.sh, jira.sh) merge into the top-level `lib/` to eliminate the nested lib.

## Architecture

### Current structure
```
etc/scripts/
├── common/                  # shared libs (detect.sh, git.sh, logging.sh, utility.sh, git_diff_commits.sh)
├── worktrees/               # worktree tool
│   ├── worktree             # entry point
│   ├── config.sh
│   ├── commands/            # subcommands
│   └── lib/                 # core.sh, jira.sh (worktree-specific libs)
├── ai/                      # AI utility scripts
├── install/                 # install scripts (arch.sh, common.sh, mac.sh)
├── install.sh               # install entry point
├── doctor.sh, kill_port.sh, pull_repos.sh, sdk_*.sh, etc.  # loose scripts
└── zellij_*.sh, ghostty_*.sh, slack_*.sh                   # loose scripts
```

### Target structure
```
etc/scripts/
├── lib/                     # ALL shared libraries (merged common/ + worktrees/lib/)
│   ├── detect.sh
│   ├── git.sh
│   ├── logging.sh
│   ├── utility.sh
│   ├── git_diff_commits.sh
│   ├── worktree_core.sh     # was worktrees/lib/core.sh
│   └── jira.sh              # was worktrees/lib/jira.sh
└── src/
    ├── worktrees/            # worktree tool (moved from worktrees/)
    │   ├── worktree          # entry point
    │   ├── config.sh
    │   └── commands/         # checkout, clean, create, delete, move, rename, update
    ├── ai/                   # AI utility scripts (moved from ai/)
    │   ├── changelog.sh
    │   ├── check-deps.sh
    │   ├── detect-stack.sh
    │   ├── fms-export-new.sh
    │   ├── git-branch-info.sh
    │   ├── install-deps.sh
    │   ├── lint-check.sh
    │   ├── pr-status.sh
    │   ├── run-tests.sh
    │   ├── scaffold-spec.sh
    │   ├── security-scan.sh
    │   ├── validate-opencode.sh
    │   └── weekly-summary.sh
    ├── install/              # install scripts (moved from install/)
    │   ├── install.sh        # was etc/scripts/install.sh
    │   ├── arch.sh
    │   ├── common.sh
    │   └── mac.sh
    ├── system/               # system utilities
    │   ├── doctor.sh
    │   ├── kill_port.sh
    │   └── sync_links.sh
    ├── dev/                  # development workflow
    │   ├── pull_repos.sh
    │   ├── sdk_install.sh
    │   ├── sdk_select.sh
    │   ├── select_git_folder_actx.sh
    │   └── slack_post_prs.sh
    └── terminal/             # terminal/multiplexer
        ├── ghostty_zellij_startup.sh
        ├── zellij_close_and_reindex.sh
        └── zellij_update_tab_indexes.sh
```

## Data flow

Not applicable (directory restructure, no data pipeline).

## Tasks

### Group 1: Create new directory structure and move files

#### Task 1: Create directories
- **Action**: `mkdir -p etc/scripts/lib etc/scripts/src/{worktrees,ai,install,system,dev,terminal}`
- **Complexity**: small
- **Dependencies**: none

#### Task 2: Move `common/` contents to `lib/`
- **Action**: `git mv etc/scripts/common/* etc/scripts/lib/` then `rmdir etc/scripts/common`
- **Complexity**: small
- **Dependencies**: Task 1
- **Sequential**: must happen before Task 5

#### Task 3: Move `worktrees/lib/` contents to `lib/`
- **Action**: 
  - `git mv etc/scripts/worktrees/lib/core.sh etc/scripts/lib/worktree_core.sh`
  - `git mv etc/scripts/worktrees/lib/jira.sh etc/scripts/lib/jira.sh`
  - `rmdir etc/scripts/worktrees/lib`
- **Note**: Rename core.sh to worktree_core.sh to avoid name collision and clarify purpose
- **Complexity**: small
- **Dependencies**: Task 1
- **Sequential**: must happen before Task 5

#### Task 4: Move entry-point scripts to `src/` categories
- **Action**: git mv each file to its category:
  - `git mv etc/scripts/worktrees/{worktree,config.sh,commands/} etc/scripts/src/worktrees/`
  - `git mv etc/scripts/ai/* etc/scripts/src/ai/`
  - `git mv etc/scripts/install/{arch,common,mac}.sh etc/scripts/src/install/`
  - `git mv etc/scripts/install.sh etc/scripts/src/install/install.sh`
  - `git mv etc/scripts/{doctor,kill_port,sync_links}.sh etc/scripts/src/system/`
  - `git mv etc/scripts/{pull_repos,sdk_install,sdk_select,select_git_folder_actx,slack_post_prs}.sh etc/scripts/src/dev/`
  - `git mv etc/scripts/{ghostty_zellij_startup,zellij_close_and_reindex,zellij_update_tab_indexes}.sh etc/scripts/src/terminal/`
- **Complexity**: medium
- **Dependencies**: Task 1
- **Sequential**: must happen before Task 5

### Group 2: Update all internal source paths

#### Task 5: Update `lib/` files' internal references
- **Files**: `lib/worktree_core.sh`
- **Action**: Update source paths from `../../common/` to relative `./` or absolute via SCRIPT_DIR:
  - `source "${0:A:h}/../../common/utility.sh"` → `source "${0:A:h}/utility.sh"`
  - `source "${0:A:h}/../../common/detect.sh"` → `source "${0:A:h}/detect.sh"`
  - `source "${0:A:h}/../../common/git.sh"` → `source "${0:A:h}/git.sh"`
- **Complexity**: small
- **Dependencies**: Tasks 2, 3

#### Task 6: Update `src/ai/*.sh` source paths
- **Files**: All 13 scripts in `src/ai/`
- **Action**: Change `source "$SCRIPT_DIR/../common/..."` to `source "$SCRIPT_DIR/../../lib/..."`
- **Complexity**: small
- **Dependencies**: Tasks 2, 4

#### Task 7: Update `src/worktrees/worktree` source paths
- **File**: `src/worktrees/worktree`
- **Action**: Update source lines:
  - `source "$SCRIPT_DIR/lib/core.sh"` → `source "$SCRIPT_DIR/../../lib/worktree_core.sh"`
  - `source "$SCRIPT_DIR/lib/jira.sh"` → `source "$SCRIPT_DIR/../../lib/jira.sh"`
  - `source "$SCRIPT_DIR/config.sh"` stays the same (relative)
  - `source "$SCRIPT_DIR/commands/*.sh"` stays the same
- **Complexity**: small
- **Dependencies**: Tasks 3, 4

#### Task 8: Update `src/install/install.sh` source paths
- **File**: `src/install/install.sh`
- **Action**: Update references to `install/arch.sh`, `install/common.sh`, `install/mac.sh` (now same directory)
- **Complexity**: small
- **Dependencies**: Task 4

#### Task 9: Update `src/system/doctor.sh` paths
- **File**: `src/system/doctor.sh`
- **Action**: Update self-reference path in error message
- **Complexity**: small
- **Dependencies**: Task 4

#### Task 10: Update `src/terminal/zellij_close_and_reindex.sh`
- **File**: `src/terminal/zellij_close_and_reindex.sh`
- **Action**: Update path to `zellij_update_tab_indexes.sh` (now in same directory)
- **Complexity**: small
- **Dependencies**: Task 4

### Group 3: Update external references

#### Task 11: Update `src/.zshrc` aliases and source paths
- **File**: `src/.zshrc`
- **Action**: Update all `$DOTFILES_DIR/etc/scripts/...` paths:
  - `etc/scripts/worktrees/worktree` → `etc/scripts/src/worktrees/worktree`
  - `etc/scripts/common/git_diff_commits.sh` → `etc/scripts/lib/git_diff_commits.sh`
  - `etc/scripts/common/utility.sh` → `etc/scripts/lib/utility.sh`
  - `etc/scripts/kill_port.sh` → `etc/scripts/src/system/kill_port.sh`
  - `etc/scripts/sdk_select.sh` → `etc/scripts/src/dev/sdk_select.sh`
  - `etc/scripts/sdk_install.sh` → `etc/scripts/src/dev/sdk_install.sh`
  - `etc/scripts/select_git_folder_actx.sh` → `etc/scripts/src/dev/select_git_folder_actx.sh`
  - `etc/scripts/pull_repos.sh` → `etc/scripts/src/dev/pull_repos.sh`
  - `etc/scripts/install.sh` → `etc/scripts/src/install/install.sh`
  - `etc/scripts/sync_links.sh` → `etc/scripts/src/system/sync_links.sh`
  - `etc/scripts/slack_post_prs.sh` → `etc/scripts/src/dev/slack_post_prs.sh`
  - `etc/scripts/zellij_update_tab_indexes.sh` → `etc/scripts/src/terminal/zellij_update_tab_indexes.sh`
  - `etc/scripts/ghostty_zellij_startup.sh` → `etc/scripts/src/terminal/ghostty_zellij_startup.sh`
  - `etc/scripts/worktrees` (in wn/wo functions) → `etc/scripts/src/worktrees`
- **Complexity**: medium (many paths, must not miss any)
- **Dependencies**: Task 4

#### Task 12: Update `src/opencode/AGENTS.md`
- **File**: `src/opencode/AGENTS.md`
- **Action**: Update references:
  - `etc/scripts/ai/` → `etc/scripts/src/ai/`
  - `common/logging.sh` → `lib/logging.sh`
  - Update script table paths
- **Complexity**: small
- **Dependencies**: Task 4

#### Task 13: Update `AGENTS.md` (root)
- **File**: `AGENTS.md`
- **Action**: Update `etc/scripts/sync_links.sh` → `etc/scripts/src/system/sync_links.sh`
- **Complexity**: small
- **Dependencies**: Task 4

#### Task 14: Update `src/opencode/command/weekly-summary.md`
- **File**: `src/opencode/command/weekly-summary.md`
- **Action**: Update `etc/scripts/ai/weekly-summary.sh` → `etc/scripts/src/ai/weekly-summary.sh`
- **Complexity**: small
- **Dependencies**: Task 4

#### Task 15: Update `src/opencode/skills/git-worktree-workflow/SKILL.md`
- **File**: `src/opencode/skills/git-worktree-workflow/SKILL.md`
- **Action**: Update `etc/scripts/worktrees/` → `etc/scripts/src/worktrees/`
- **Complexity**: small
- **Dependencies**: Task 4

#### Task 16: Update `src/opencode/skills/meta-shell-scripting/SKILL.md`
- **File**: `src/opencode/skills/meta-shell-scripting/SKILL.md`
- **Action**: Update `etc/scripts/common/logging.sh` → `etc/scripts/lib/logging.sh`
- **Complexity**: small
- **Dependencies**: Task 4

#### Task 17: Update `etc/docs/setup_common.md`
- **File**: `etc/docs/setup_common.md`
- **Action**: Update script paths
- **Complexity**: small
- **Dependencies**: Task 4

## API contracts

No new APIs. All function signatures remain identical. Only file paths change.

## State changes

No new state. The `$DOTFILES_DIR/etc/scripts/` path prefix remains the same; only subdirectory structure changes.

## Edge cases

- **Symlinks**: `sync_links.sh` creates symlinks from `src/` to destinations. After moving it to `src/system/sync_links.sh`, its own path references and any paths it constructs relative to itself need updating.
- **install.sh**: Currently at `etc/scripts/install.sh`, it sources `install/arch.sh` etc. After move to `src/install/install.sh`, the sub-scripts are in the same directory.
- **SCRIPT_DIR in worktree commands**: The commands use `${0:A:h}` (zsh) to find their directory. After move to `src/worktrees/commands/`, this still works since they're sourced from the `worktree` entry point which sets `SCRIPT_DIR`.
- **get_org_dirs**: Referenced from both bash (utility.sh) and zsh (worktree_core.sh sources utility.sh). Must remain shell-agnostic.
- **Stale git tracked paths**: After `git mv`, old paths are automatically removed from tracking. No manual cleanup needed.

## Testing approach

- After all moves: run `zsh -n` on all .sh files to verify syntax
- Source `.zshrc` in a new shell to verify all aliases resolve
- Run `wD` (worktree delete), `detect-stack.sh --help`, `install-deps.sh --help` to verify scripts still work
- Run `grep -r 'etc/scripts/common/' etc/ src/` to verify no stale references to old `common/` path remain
- Run `grep -r 'worktrees/lib/' etc/ src/` to verify no stale references to old `worktrees/lib/` path remain

## Open questions

All resolved.

### Decisions
- **Structure**: `lib/` + `src/` under `etc/scripts/`, with `src/` grouped by category
- **worktrees/lib merge**: core.sh and jira.sh move into top-level lib/ (renamed to worktree_core.sh and jira.sh)
- **Standalone scripts**: Grouped by category in src/ (system, dev, terminal)
