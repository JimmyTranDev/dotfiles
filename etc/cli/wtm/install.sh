#!/bin/bash

# Install script for wtm (Worktree Manager)
# This script builds the Go binary and optionally installs it to a location in PATH

set -e

CLI_DIR="/Users/jimmy/Programming/dotfiles/etc/cli/wtm"
BUILD_TARGET="wtm"

echo "Building wtm CLI..."
cd "$CLI_DIR"
go build -o "$BUILD_TARGET" .

echo "✅ Build successful!"

# Ask user if they want to install globally
read -p "Install wtm to /usr/local/bin for global access? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Installing wtm to /usr/local/bin..."
    sudo cp "$BUILD_TARGET" /usr/local/bin/
    echo "✅ wtm installed globally!"
    echo "You can now run 'wtm' from anywhere."
else
    echo "Binary available at: $CLI_DIR/$BUILD_TARGET"
    echo "To use globally, add this to your shell config:"
    echo "  export PATH=\"$CLI_DIR:\$PATH\""
    echo "Or create a symlink:"
    echo "  ln -s $CLI_DIR/$BUILD_TARGET /usr/local/bin/wtm"
fi

echo ""
echo "🎉 Setup complete! Run 'wtm --help' to get started."