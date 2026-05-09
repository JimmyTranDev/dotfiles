# Automate Secrets Sync: SSH, Templates, and Espanso

## TL;DR
- Move `.gitconfig`, `.npmrc`, `.m2/settings.xml` from template generation to pre-rendered files in `secrets/` synced via symlinks
- Add SSH config (`~/.ssh/`) as a symlinked directory from `secrets/`
- Replace Espanso `personal.yml` shell-sourcing pattern with a pre-rendered file in `secrets/` symlinked into the espanso config
- Remove `etc/templates/` directory and `generate_from_template` logic from `common.sh`
- 9 tasks, estimated effort: small-medium (2-3 hours)

## Overview

Currently the dotfiles install process uses `sed`-based template generation to produce `.gitconfig`, `.npmrc`, and `.m2/settings.xml` from templates + secret env vars. Espanso's `personal.yml` sources `env.sh` via 27 separate shell commands at runtime. SSH has no automation at all.

This spec consolidates everything into a single approach: pre-rendered config files live in the `secrets/` repo and are symlinked to their destinations via `sync_links.sh`.

## Architecture

```
secrets/                          (private repo, synced via Bitwarden)
├── env.sh                        (keep - still used by .zshrc and other scripts)
├── ssh/                          (NEW - contains id_ed25519, id_ed25519.pub, config, known_hosts)
├── .gitconfig                    (NEW - fully rendered, no placeholders)
├── .npmrc                        (NEW - fully rendered, no placeholders)
├── .m2/settings.xml              (NEW - fully rendered, no placeholders)
├── espanso/match/personal.yml    (NEW - hardcoded values, no shell sourcing)
└── links.json                    (existing)

dotfiles/
├── etc/templates/                (DELETED)
├── src/espanso/match/personal.yml (DELETED - replaced by secrets version)
└── etc/scripts/src/install/
    ├── sync_links.sh             (MODIFIED - add new secret symlinks)
    └── common.sh                 (MODIFIED - remove template generation)
```

The symlink flow for secrets files:
- `secrets/ssh/` -> `~/.ssh`
- `secrets/.gitconfig` -> `~/.gitconfig`
- `secrets/.npmrc` -> `~/.npmrc`
- `secrets/.m2/` -> `~/.m2`
- `secrets/espanso/match/personal.yml` -> `~/.config/espanso/match/personal.yml`

## Data Flow

1. User runs `install.sh` (or `sync_links.sh` directly)
2. `sync_links.sh` reads link mappings including new secrets-based entries
3. For each mapping, it creates a symlink from source to destination (backing up existing files)
4. No template rendering step needed - files in `secrets/` are already fully rendered
5. Espanso reads `personal.yml` directly with hardcoded values instead of spawning 27 shell processes

## Tasks

### Task 1: Create pre-rendered config files in secrets repo
- **Files**: `~/Programming/JimmyTranDev/secrets/.gitconfig`, `secrets/.npmrc`, `secrets/.m2/settings.xml`
- **What**: Take the current templates from `etc/templates/`, substitute all `{{PLACEHOLDER}}` values with the actual values from `env.sh`, and save as complete files in the `secrets/` repo
- **Complexity**: small
- **Parallel**: yes (independent of other tasks)
- **Dependencies**: none

### Task 2: Create SSH directory in secrets repo
- **Files**: `~/Programming/JimmyTranDev/secrets/ssh/`
- **What**: Move existing `~/.ssh/id_ed25519`, `~/.ssh/id_ed25519.pub`, `~/.ssh/known_hosts`, and `~/.ssh/agent/` into `secrets/ssh/`. Create an SSH config file at `secrets/ssh/config` with `AddKeysToAgent yes`, `IdentityFile ~/.ssh/id_ed25519`, and common host entries (github.com). Set proper permissions (700 for dir, 600 for private key).
- **Complexity**: small
- **Parallel**: yes
- **Dependencies**: none

### Task 3: Create pre-rendered Espanso personal.yml in secrets repo
- **Files**: `~/Programming/JimmyTranDev/secrets/espanso/match/personal.yml`
- **What**: Replace all `type: shell` global_vars with hardcoded values directly. Each variable becomes a simple `name`/`params.value` pair. Keep the `matches:` section identical. Delete `src/espanso/match/personal.yml` from the dotfiles repo.
- **Complexity**: small
- **Parallel**: yes
- **Dependencies**: none

### Task 4: Update sync_links.sh to include secrets symlinks
- **File**: `etc/scripts/src/install/sync_links.sh`
- **What**: Add these entries to `get_common_links()`:
  ```
  "$SECRETS_DIR/ssh|$HOME/.ssh"
  "$SECRETS_DIR/.gitconfig|$HOME/.gitconfig"
  "$SECRETS_DIR/.npmrc|$HOME/.npmrc"
  "$SECRETS_DIR/.m2|$HOME/.m2"
  "$SECRETS_DIR/espanso/match/personal.yml|$HOME/.config/espanso/match/personal.yml"
  ```
  Define `SECRETS_DIR="$HOME/Programming/JimmyTranDev/secrets"` at the top. Add `mkdir -p "$HOME/.config/espanso/match"` to the setup section. Handle SSH directory permissions after linking (chmod 700 on `~/.ssh`, chmod 600 on private keys).
- **Complexity**: medium
- **Parallel**: no (depends on Tasks 1-3 existing)
- **Dependencies**: Tasks 1, 2, 3

### Task 5: Remove template generation from common.sh
- **File**: `etc/scripts/src/install/common.sh`
- **What**: Remove the entire `generate_from_template` function and the three `generate_from_template` calls (lines 43-77). The `source "$SECRETS_ENV"` line can also be removed since templates no longer need it. Keep `SECRETS_ENV` reference only if other parts use it (check `.zshrc`).
- **Complexity**: small
- **Parallel**: no (do after Task 4)
- **Dependencies**: Task 4

### Task 6: Delete etc/templates/ directory
- **Files**: `etc/templates/.gitconfig`, `etc/templates/.npmrc`, `etc/templates/.m2/settings.xml`
- **What**: `git rm -r etc/templates/`
- **Complexity**: small
- **Parallel**: yes (after Task 5)
- **Dependencies**: Task 5

### Task 7: Remove personal.yml from dotfiles espanso config
- **File**: `src/espanso/match/personal.yml`
- **What**: Delete this file from the dotfiles repo since it's now symlinked from secrets. The espanso directory symlink (`src/espanso` -> `~/.config/espanso`) still exists, so the secrets `personal.yml` needs to be symlinked INTO the dotfiles `src/espanso/match/` directory, OR the secrets version symlinks directly to `~/.config/espanso/match/personal.yml` (which the dotfiles symlink already points to `src/espanso/match/`). Since `src/espanso` is symlinked as a directory, the personal.yml inside it will be the dotfiles version. Solution: keep `personal.yml` in dotfiles but make it a symlink to secrets, OR change the sync approach to symlink secrets personal.yml after the espanso dir is linked. The latter is simpler - `sync_links.sh` processes links in order, so add the personal.yml link AFTER the espanso directory link. The file-level symlink will be created inside the already-linked directory.
- **Complexity**: small
- **Parallel**: no (after Task 4)
- **Dependencies**: Task 4

### Task 8: Update doctor.sh health checks
- **File**: `etc/scripts/src/install/doctor.sh`
- **What**: Add checks for the new symlinks (SSH dir exists and has correct permissions, .gitconfig is a symlink, .npmrc is a symlink, espanso personal.yml is a symlink). Remove any template-related checks if they exist.
- **Complexity**: small
- **Parallel**: yes (after Task 5)
- **Dependencies**: Task 5

### Task 9: Remove ESPANSO_* variables from env.sh
- **File**: `~/Programming/JimmyTranDev/secrets/env.sh`
- **What**: Remove all `export ESPANSO_*` lines (lines 30-56) since values are now hardcoded in the Espanso YAML.
- **Complexity**: small
- **Parallel**: yes (after Task 3)
- **Dependencies**: Task 3

## API Contracts

N/A - no APIs involved.

## State Changes

- **New files in secrets repo**: `.gitconfig`, `.npmrc`, `.m2/settings.xml`, `ssh/` directory, `espanso/match/personal.yml`
- **Deleted from dotfiles**: `etc/templates/` directory, `src/espanso/match/personal.yml` content (replaced with symlink or deleted)
- **Modified**: `sync_links.sh` (new link entries), `common.sh` (removed template logic), `doctor.sh` (new checks)
- **No new env variables** - this change reduces env var usage

## Edge Cases

1. **First-time install without secrets repo**: `sync_links.sh` already handles missing sources with a warning and skip. The new secret symlinks will just be skipped.
2. **SSH permissions**: Symlinked SSH directory must maintain 700/600 permissions or SSH will refuse to use the keys. Add a post-link `chmod` step.
3. **Espanso symlink ordering**: The personal.yml symlink must be processed AFTER the espanso directory symlink, since it targets a path inside the linked directory. Ensure ordering in the links array.
4. **Existing non-symlink files**: The backup mechanism in `sync_links.sh` already handles this - existing real files get backed up before symlink creation.
5. **secrets repo not cloned yet**: On a fresh machine, `bootstrap.sh` downloads secrets from Bitwarden before running `install.sh`, so secrets should be available.

## Testing Approach

- **Manual verification**: Run `sync_links.sh --dry-run` to confirm all new links would be created correctly
- **Post-install checks**: Run `doctor.sh` to verify all symlinks and permissions
- **SSH test**: `ssh -T git@github.com` should still authenticate
- **Espanso test**: Verify triggers like `;pe` still expand correctly (and faster, without shell sourcing)
- **Git test**: `git config user.email` should return the correct email
- **npm test**: `npm config get registry` should work, scoped registries should resolve

## Open Questions

All resolved:

1. **SSH known_hosts**: Decision: Sync via secrets repo.
2. **SSH agent config**: Decision: Create SSH config with `AddKeysToAgent yes` and `IdentityFile` directives.
3. **Espanso personal.yml approach**: Decision: Delete from dotfiles repo, symlink from secrets at install time.
4. **env.sh cleanup**: Decision: Remove all `ESPANSO_*` exports from env.sh.
