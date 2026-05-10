# Arch Linux Setup

## Bootstrap (single command)

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JimmyTranDev/dotfiles/main/etc/scripts/src/install/bootstrap.sh)"
```

This will:
1. Install git via pacman
2. Clone dotfiles
3. Download secrets from Bitwarden
4. Switch dotfiles remote to SSH
5. Install SDKMAN
6. Run the full install script (symlinks, packages, etc.)

## Prerequisites

- A working Arch Linux installation with `pacman` and `curl` available
- `yay` (AUR helper) recommended for additional packages installed by the install script
