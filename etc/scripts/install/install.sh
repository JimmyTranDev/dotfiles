#!/bin/bash

# Dotfiles Installation Script
# This script sets up the development environment by installing dependencies and syncing configurations

set -e  # Exit on any error

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/etc/scripts"

echo "🚀 Starting dotfiles installation..."
echo "📁 Dotfiles directory: $DOTFILES_DIR"

# Make scripts executable
chmod +x "$SCRIPTS_DIR"/*.sh

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "📦 Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended
fi

# Clone nvim config if it doesn't exist
if [ ! -d "$HOME/Programming/nvim" ]; then
    echo "⚙️  Cloning nvim configuration..."
    mkdir -p "$HOME/Programming"
    git clone git@github.com:JimmyTranDev/nvim-config.git "$HOME/Programming/nvim"
fi

# Run sync scripts
echo "🔗 Syncing symbolic links..."
"$SCRIPTS_DIR/sync_links.sh"

echo "🔐 Syncing secrets..."
"$SCRIPTS_DIR/sync_secrets.sh"

echo "📦 Syncing packages..."
"$SCRIPTS_DIR/sync_packages.sh"

echo "✅ Dotfiles installation completed successfully!"
echo "🔄 Please restart your terminal or run 'source ~/.zshrc' to apply changes."