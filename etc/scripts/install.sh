#!/bin/bash

# Dotfiles Installation Script
# Detects the platform and runs common + platform-specific setup

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install"

echo "Starting dotfiles installation..."

# Run common setup (oh-my-zsh, nvim, symlinks, secrets)
"$INSTALL_DIR/common.sh"

# Detect platform and run platform-specific setup
if [ "$(uname)" == "Darwin" ]; then
	"$INSTALL_DIR/mac.sh"
elif [ "$(uname)" == "Linux" ]; then
	if [ -f /etc/arch-release ]; then
		"$INSTALL_DIR/arch.sh"
	else
		echo "Unsupported Linux distribution. Only Arch Linux is currently supported."
		exit 1
	fi
else
	echo "Unknown platform: $(uname)"
	exit 1
fi

echo "Dotfiles installation completed successfully!"
echo "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
