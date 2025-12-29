#!/bin/bash

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Android/Termux setup script"
echo "📱 This script will install essential development tools using pkg"

# Check if we're running in Termux
if [[ ! -d "$PREFIX" ]]; then
  echo "⚠️ This script is designed for Termux on Android"
  echo "Please run this in Termux environment"
  exit 1
fi

# Update package lists
echo "📦 Updating package lists..."
pkg update -y

# Essential packages only - core development tools
packages=(
  git
  neovim
  zsh
  nodejs
  python
  curl
)

echo "📦 Installing essential packages..."
for pkg_name in "${packages[@]}"; do
  echo "Installing $pkg_name..."
  pkg install -y "$pkg_name" || echo "⚠️ Failed to install $pkg_name, continuing..."
done

# Setup storage access for Termux
echo "📂 Setting up storage access..."
if [[ ! -d "$HOME/storage" ]]; then
  termux-setup-storage
  echo "📂 Storage access configured"
else
  echo "📂 Storage access already configured"
fi

# Install pnpm if nodejs was installed successfully
if command -v npm >/dev/null 2>&1; then
  echo "📦 Installing pnpm..."
  npm install -g pnpm || echo "⚠️ Failed to install pnpm"
fi

# Setup dotfiles if the Programming directory exists
if [[ -d "$HOME/Programming/dotfiles" ]]; then
  echo "🔗 Setting up dotfiles..."
  
  # Run the link script if it exists
  if [[ -f "$SCRIPT_DIR/sync_links.sh" ]]; then
    "$SCRIPT_DIR/sync_links.sh" create
    echo "🔗 Dotfiles linked successfully"
  else
    echo "⚠️ Link script not found, skipping dotfiles setup"
  fi
else
  echo "📁 Dotfiles directory not found at $HOME/Programming/dotfiles"
  echo "💡 Clone your dotfiles first if you want to set them up"
fi

# Setup shell to zsh if installed
if command -v zsh >/dev/null 2>&1; then
  echo "🐚 Setting up Zsh as default shell..."
  chsh -s zsh || echo "💡 You can manually switch to zsh by running 'zsh'"
else
  echo "⚠️ Zsh not installed, keeping current shell"
fi

# Setup Git configuration prompt
echo "🔧 Git configuration check..."
if command -v git >/dev/null 2>&1; then
  if [[ -z "$(git config --global user.name)" ]] || [[ -z "$(git config --global user.email)" ]]; then
    echo "💡 Remember to configure Git:"
    echo "   git config --global user.name 'Your Name'"
    echo "   git config --global user.email 'your.email@example.com'"
  else
    echo "✅ Git already configured"
  fi
fi

# Final setup message
echo ""
echo "✅ Android/Termux setup completed!"
echo ""
echo "📱 Next steps:"
echo "   1. Run 'zsh' to use the new shell"
echo "   2. Configure Git with your name and email"
echo "   3. Run 'nvim' to start using Neovim"
echo ""
echo "🎉 Happy coding on Android!"