#!/bin/bash

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect platform and handle Android/Termux first
if [[ -d "$PREFIX" ]]; then
  echo "🚀 Detected Android/Termux. Running Termux setup..."
  
  # Update package lists
  echo "📦 Updating package lists..."
  pkg update -y
  
  # Essential packages - comprehensive development environment
  packages=(
    # Core development tools
    git
    neovim
    zsh
    nodejs
    python
    curl
    
    # Shell and terminal enhancements
    fzf
    zoxide
    starship
    
    # File management and utilities
    fd
    ripgrep
    tree
    unzip
    wget
    
    # Text processing
    jq
    
    # Development utilities
    openssh
    rsync
    
    # Optional but useful
    htop
    tmux
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
  
  # Create essential Android-specific configurations
  echo "📱 Setting up Android-specific configurations..."
  
  # Create a termux config directory if it doesn't exist
  mkdir -p "$HOME/.termux"
  
  # Basic termux configuration for better developer experience
  if [[ ! -f "$HOME/.termux/termux.properties" ]]; then
    cat > "$HOME/.termux/termux.properties" << 'EOF'
# Termux properties file
# Enable extra keys row for better coding experience
extra-keys = [['ESC','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN']]

# Use black background
use-black-ui = true

# Allow external apps to execute commands
allow-external-apps = true
EOF
    echo "📱 Created enhanced Termux configuration"
  fi
  
  # Setup shared storage directories for better file access
  echo "📂 Setting up development directories..."
  mkdir -p "$HOME/Programming"
  
  # Create symlinks to shared storage if available
  if [[ -d "$HOME/storage/shared" ]]; then
    # Link common development directories to shared storage
    if [[ ! -L "$HOME/Desktop" ]] && [[ -d "$HOME/storage/shared/Desktop" ]]; then
      ln -sf "$HOME/storage/shared/Desktop" "$HOME/Desktop" 2>/dev/null || true
    fi
    
    if [[ ! -L "$HOME/Downloads" ]] && [[ -d "$HOME/storage/shared/Download" ]]; then
      ln -sf "$HOME/storage/shared/Download" "$HOME/Downloads" 2>/dev/null || true
    fi
  fi
  
  # Setup shell to zsh if installed
  if command -v zsh >/dev/null 2>&1; then
    echo "🐚 Setting up Zsh as default shell..."
    chsh -s zsh || echo "💡 You can manually switch to zsh by running 'zsh'"
  else
    echo "⚠️ Zsh not installed, keeping current shell"
  fi
  
  # Comprehensive Git configuration for Android development
  echo "🔧 Git configuration setup..."
  if command -v git >/dev/null 2>&1; then
    # Set up basic Git configuration if missing
    if [[ -z "$(git config --global user.name)" ]] || [[ -z "$(git config --global user.email)" ]]; then
      echo "💡 Remember to configure Git:"
      echo "   git config --global user.name 'Your Name'"
      echo "   git config --global user.email 'your.email@example.com'"
    else
      echo "✅ Git user configuration already set"
    fi
    
    # Set up Git aliases and configurations useful for mobile development
    echo "🔧 Setting up Git enhancements..."
    git config --global init.defaultBranch main 2>/dev/null || true
    git config --global pull.rebase false 2>/dev/null || true
    git config --global core.editor "nvim" 2>/dev/null || true
    git config --global color.ui auto 2>/dev/null || true
    
    # Useful Git aliases
    git config --global alias.st status 2>/dev/null || true
    git config --global alias.co checkout 2>/dev/null || true
    git config --global alias.br branch 2>/dev/null || true
    git config --global alias.cm commit 2>/dev/null || true
    git config --global alias.lg "log --oneline --decorate --all --graph" 2>/dev/null || true
    
    echo "✅ Git configuration enhanced"
  fi

elif [ "$(uname)" == "Darwin" ]; then
  echo "🚀 Detected macOS. Running macOS setup..."

  if command -v brew >/dev/null 2>&1; then
    echo "📦 Installing Homebrew packages..."
    brew bundle --file="$HOME/Brewfile" check ||
      brew bundle --file="$HOME/Brewfile" install ||
      brew bundle --file="$HOME/Brewfile" cleanup --force
  else
    echo "⚠️ Homebrew not found. Please install Homebrew first."
  fi

elif [ "$(uname)" == "Linux" ]; then
  echo "🚀 Detected Linux. Running Linux/WSL setup..."

  # Install packages (Arch/WSL example)
  packages=(
    # --- Containers & DevOps ---
    docker
    docker-compose

    # --- Version Control & Dev Tools ---
    git
    lazygit
    starship

    # --- Editors ---
    neovim
    vim

    # --- Shell & Terminal ---
    zsh
    zellij
    fzf
    zoxide
    shfmt

    # --- File Management & Utilities ---
    fd
    ripgrep
    lsof
    xclip
    wget
    p7zip
    poppler
    ffmpegthumbnailer
    imagemagick
    jq
    yazi

    # --- Programming Languages & Tools ---
    pnpm
    python
    python-poetry
    luarocks
    clang
    gopls
  )

  echo "📦 Updating system and installing packages..."
  sudo pacman -Syu --noconfirm
  for pkg in "${packages[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg"
  done

  aurs=(fnm)
  echo "📦 Updating AUR and installing AUR packages..."
  paru -Syu --noconfirm
  for aur in "${aurs[@]}"; do
    paru -S --needed --noconfirm "$aur"
  done

fi

# Setup dotfiles for all platforms
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

# Platform-specific completion messages
if [[ -d "$PREFIX" ]]; then
  echo ""
  echo "✅ Android/Termux comprehensive setup completed!"
  echo ""
  echo "📱 What was installed:"
  echo "   • Essential development tools (git, neovim, zsh, nodejs, python)"
  echo "   • Shell enhancements (fzf, zoxide, starship)"
  echo "   • File utilities (fd, ripgrep, tree, jq)"
  echo "   • Development utilities (openssh, rsync, htop, tmux)"
  echo "   • Enhanced Termux configuration with extra keys"
  echo "   • Git aliases and configuration"
  echo "   • Shared storage directory links"
  echo ""
  echo "📱 Next steps:"
  echo "   1. Restart Termux or run 'zsh' to use the new shell"
  echo "   2. Configure Git user if not done: git config --global user.name/user.email"
  echo "   3. Run 'nvim' to start using Neovim"
  echo "   4. Use 'fzf' for fuzzy file finding"
  echo "   5. Try 'htop' for system monitoring"
  echo ""
  echo "💡 Pro tips:"
  echo "   • Use the extra keys row at the top of keyboard"
  echo "   • Files in ~/storage/shared are accessible by other apps"
  echo "   • Use 'pkg search <package>' to find more packages"
  echo ""
  echo "🎉 Happy coding on Android!"
else
  echo "✅ Setup completed successfully!"
fi
