---
todoist: https://app.todoist.com/app/section/install-extra-6gc8Hw4F36QMFcvM
---

# Install Extra Automation

## TL;DR

- 7 tasks in the "Install extra" Todoist section analyzed for automation in the dotfiles install scripts
- 4 tasks can be automated via `mac.sh` (dock, key repeat, reduce motion, mission control)
- 1 task needs adding to `common.sh` (`ya pkg install` for yazi plugins)
- 2 tasks are already resolved (bitwarden secrets sync exists in `bootstrap.sh`, acli formula now works)
- Estimated effort: small (all are one-liner `defaults write` commands or single CLI calls)

## Overview

The "Install extra" section contains post-install tweaks that should run automatically during dotfiles setup. Most are macOS `defaults write` commands that belong in `mac.sh`. One is a yazi plugin install that belongs in `common.sh`.

## Architecture

All changes go into existing scripts:
- `etc/scripts/src/install/mac.sh` — macOS-specific system preferences
- `etc/scripts/src/install/common.sh` — cross-platform tool setup

No new files needed.

## Tasks

### 1. Add `ya pkg install` to `common.sh`

- **File**: `etc/scripts/src/install/common.sh`
- **Change**: After symlinks are synced (line 39), add a block that runs `ya pkg install` if `ya` is available. This installs all yazi plugins defined in `src/yazi/package.toml`.
- **Complexity**: small
- **Parallel**: yes

```bash
if command -v ya >/dev/null 2>&1; then
	echo "Installing yazi packages..."
	ya pkg install
fi
```

### 2. Add macOS defaults to `mac.sh`

- **File**: `etc/scripts/src/install/mac.sh`
- **Change**: Add a section after the brew bundle block with the following defaults:
- **Complexity**: small
- **Parallel**: yes (all independent of each other)

#### 2a. Reduce motion (accessibility)

```bash
defaults write com.apple.universalaccess reduceMotion -bool true
```

#### 2b. Key repeat rate

```bash
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
```

#### 2c. Dock position left + auto-hide

```bash
defaults write com.apple.dock orientation -string "left"
defaults write com.apple.dock autohide -bool true
killall Dock
```

#### 2d. Mission Control — Ctrl+number switches to space

```bash
for i in {1..9}; do
	defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$((17 + i))" \
		"<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>$((48 + i))</integer><integer>$((17 + i))</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
done
```

Note: The mission control hotkeys use plist format. The modifier `262144` = Control key. This maps Ctrl+1 through Ctrl+9 to switch to Desktop 1-9. A logout/restart is required for these to take effect.

### 3. Already resolved — no action needed

| Task | Status |
|------|--------|
| "or use bitwarden cli to get and sync secrets" | Already implemented in `etc/scripts/src/install/bootstrap.sh:57-84` (`setup_bitwarden_secrets` function) |
| "acli formula warning" | Formula now works (`atlassian/acli/acli` installed successfully). Tap is in Brewfile line 4. |

## Edge Cases

- `ya pkg install` requires network access; if offline it will fail. Wrap in a non-fatal block (don't `set -e` kill the script).
- `killall Dock` restarts the Dock — acceptable during install but disruptive if run repeatedly.
- Mission Control hotkeys via `defaults write` can be fragile across macOS versions. Test on current macOS version before committing.
- Key repeat values: `KeyRepeat 2` is very fast (30ms). Some users prefer 1. `InitialKeyRepeat 15` is ~225ms.

## Testing Approach

- Manual verification: run `mac.sh`, then check System Settings to confirm dock is left/auto-hide, key repeat is fast, reduce motion is on.
- For mission control: open System Settings > Keyboard > Shortcuts > Mission Control and verify Ctrl+1 through Ctrl+9 are assigned.
- For yazi: run `ya pkg list` after install and confirm plugins match `package.toml`.

## Decisions

- **Key repeat values**: KeyRepeat=2, InitialKeyRepeat=15 (confirmed)
- **Mission Control spaces**: Ctrl+1 through Ctrl+9 (all 9)
- **Resolved Todoist tasks**: Left open (not auto-completed)
