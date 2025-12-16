#!/usr/bin/env bash

# Build script for dotfiles CLI
set -euo pipefail

VERSION=${1:-"dev"}
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Building dotfiles CLI..."
echo "Version: $VERSION"
echo "Commit: $COMMIT" 
echo "Date: $DATE"

# Build for current platform
go build -ldflags "-X main.version=$VERSION -X main.commit=$COMMIT -X main.date=$DATE" -o dotfiles .

echo "✓ Build complete: ./dotfiles"