#!/bin/bash

# macOS package installation

set -e

echo "Running macOS setup..."

if command -v brew >/dev/null 2>&1; then
	echo "Installing Homebrew packages..."
	brew bundle --file="$HOME/Brewfile" check ||
		brew bundle --file="$HOME/Brewfile" install
	brew bundle --file="$HOME/Brewfile" cleanup --force
else
	echo "Homebrew not found. Please install Homebrew first:"
	echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
	exit 1
fi

echo "macOS setup completed"
