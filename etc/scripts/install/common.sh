#!/bin/bash

# Common installation steps shared across all platforms

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/etc/scripts"

source "$SCRIPTS_DIR/common/utility.sh"

echo "Running common setup..."

# Make scripts executable
find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	echo "Installing Oh My Zsh..."
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
	echo "Oh My Zsh already installed"
fi

# Clone nvim config if it doesn't exist
if [ ! -d "$HOME/Programming/JimmyTranDev/nvim" ]; then
	echo "Cloning nvim configuration..."
	mkdir -p "$HOME/Programming/JimmyTranDev"
	if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
		git clone git@github.com:JimmyTranDev/nvim-config.git "$HOME/Programming/JimmyTranDev/nvim"
	else
		git clone https://github.com/JimmyTranDev/nvim-config.git "$HOME/Programming/JimmyTranDev/nvim"
	fi
else
	echo "Nvim config already exists"
fi

echo "Syncing symbolic links..."
"$SCRIPTS_DIR/sync_links.sh"

if [[ -n "$PRI_B2_BUCKET_NAME" ]]; then
	echo "Syncing secrets..."
	"$SCRIPTS_DIR/sync_secrets.sh"
else
	echo "Skipping secrets sync (PRI_B2_BUCKET_NAME not set)"
fi

echo "Common setup completed"
