#!/bin/bash

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Android/Termux setup script"
echo "📱 This script will install Neovim and essential tools using pkg"

# Check if we're running in Termux
if [[ ! -d "$PREFIX" ]]; then
  echo "⚠️ This script is designed for Termux on Android"
  echo "Please run this in Termux environment"
  exit 1
fi

# Update package lists
echo "📦 Updating package lists..."
pkg update -y

# Core packages for development environment
packages=(
  # --- Essential Tools ---
  git
  neovim
  openssh
  curl
  wget
  
  # --- Shell & Terminal ---
  zsh
  fzf
  
  # --- File Management & Utilities ---
  fd
  ripgrep
  jq
  tree
  zip
  unzip
  
  # --- Programming Languages & Tools ---
  python
  nodejs
  clang
  
  # --- Text Processing ---
  sed
  awk
  grep
  
  # --- Network Tools ---
  nmap
  rsync
)

echo "📦 Installing essential packages..."
for pkg_name in "${packages[@]}"; do
  echo "Installing $pkg_name..."
  pkg install -y "$pkg_name" || echo "⚠️ Failed to install $pkg_name, continuing..."
done

# Install additional useful packages
additional_packages=(
  # --- Optional but useful ---
  htop
  nano
  tmux
  figlet
  cowsay
  fortune
)

echo "📦 Installing additional packages..."
for pkg_name in "${additional_packages[@]}"; do
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
  if [[ -f "$SCRIPT_DIR/install/link.sh" ]]; then
    "$SCRIPT_DIR/install/link.sh" create
    echo "🔗 Dotfiles linked successfully"
  else
    echo "⚠️ Link script not found, skipping dotfiles setup"
  fi
else
  echo "📁 Dotfiles directory not found at $HOME/Programming/dotfiles"
  echo "📥 Cloning dotfiles repository..."
  
  # Create Programming directory if it doesn't exist
  mkdir -p "$HOME/Programming"
  
  # Clone dotfiles (assuming it's available somewhere)
  echo "🔄 You may need to manually clone your dotfiles repository:"
  echo "   cd $HOME/Programming"
  echo "   git clone <your-dotfiles-repo-url> dotfiles"
fi

# Setup shell to zsh if installed
if command -v zsh >/dev/null 2>&1; then
  echo "🐚 Setting up Zsh as default shell..."
  
  # In Termux, we need to change the shell differently
  if [[ "$SHELL" != *"zsh"* ]]; then
    chsh -s zsh || echo "⚠️ Could not change default shell to zsh"
    echo "💡 You can manually switch to zsh by running 'zsh' or add it to your .bashrc"
  fi
else
  echo "⚠️ Zsh not installed, keeping current shell"
fi

# Create useful Android-specific aliases and functions
echo "📱 Creating Android-specific configurations..."

# Create a termux config directory if it doesn't exist
mkdir -p "$HOME/.termux"

# Basic termux configuration
if [[ ! -f "$HOME/.termux/termux.properties" ]]; then
  cat > "$HOME/.termux/termux.properties" << 'EOF'
# Termux properties file
# Enable extra keys row
extra-keys = [['ESC','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN']]

# Use black background
use-black-ui = true

# Allow external apps to execute commands
allow-external-apps = true
EOF
  echo "📱 Created basic Termux configuration"
fi

# Setup Git configuration prompt
if command -v git >/dev/null 2>&1; then
  echo "🔧 Git configuration check..."
  
  if [[ -z "$(git config --global user.name)" ]]; then
    echo "📝 Git user name not configured"
    echo "💡 Run: git config --global user.name 'Your Name'"
  fi
  
  if [[ -z "$(git config --global user.email)" ]]; then
    echo "📝 Git user email not configured"
    echo "💡 Run: git config --global user.email 'your.email@example.com'"
  fi
fi

# Final setup message
echo ""
echo "✅ Android/Termux setup completed successfully!"
echo ""
echo "📱 Next steps:"
echo "   1. Restart Termux or run 'zsh' to use the new shell"
echo "   2. Configure Git with your name and email if not done"
echo "   3. Clone your dotfiles if not already present"
echo "   4. Run 'nvim' to start using Neovim"
echo ""
echo "💡 Useful commands:"
echo "   - 'termux-setup-storage' for file access"
echo "   - 'pkg search <package>' to find packages"
echo "   - 'pkg list-installed' to see installed packages"
echo ""
echo "🎉 Happy coding on Android!"