# Mac Setup

## Bootstrap (single command)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/JimmyTranDev/dotfiles/main/etc/scripts/src/install/bootstrap.sh)"
```

This will:
1. Install Xcode Command Line Tools (git)
2. Install Homebrew
3. Clone dotfiles
4. Download secrets from Bitwarden
5. Switch dotfiles remote to SSH
6. Install SDKMAN
7. Run the full install script (symlinks, packages, etc.)
8. Start yabai and skhd services

## Post-Bootstrap Manual Steps

### Connect OpenCode

1. Open a terminal and run `opencode`
2. Connect to GitHub Copilot when prompted

### Raycast

1. Open Raycast and grant accessibility permissions
2. Set Cmd+Space as Raycast hotkey (replaces Spotlight)
3. Install extensions: Clipboard History, Window Management, etc.

### Reduce Motion

1. System Settings > Accessibility > Display
2. Enable "Reduce motion"

### Key Repeat Rate

1. System Settings > Keyboard
2. Set "Key repeat rate" to fastest
3. Set "Delay until repeat" to shortest

### Dock

1. System Settings > Desktop & Dock
2. Set position to "Left"
3. Enable "Automatically hide and show the Dock"

### Mission Control Keyboard Shortcuts

1. System Settings > Keyboard > Keyboard Shortcuts > Mission Control
2. Enable "Switch to Desktop 1" through "Switch to Desktop 10"
3. Set shortcuts to ctrl+1 through ctrl+0
