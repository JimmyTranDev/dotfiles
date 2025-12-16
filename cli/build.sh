#!/usr/bin/env bash
# Build script for dotfiles CLI
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Version information
VERSION=${1:-"dev"}
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build flags
LDFLAGS="-X main.version=$VERSION -X main.commit=$COMMIT -X main.date=$DATE -s -w"

echo -e "${BLUE}Building dotfiles CLI...${NC}"
echo -e "  Version: ${YELLOW}$VERSION${NC}"
echo -e "  Commit:  ${YELLOW}$COMMIT${NC}"
echo -e "  Date:    ${YELLOW}$DATE${NC}"
echo

# Validate environment
if ! command -v go >/dev/null 2>&1; then
    echo -e "${RED}Error: Go is not installed or not in PATH${NC}" >&2
    exit 1
fi

# Clean previous builds
if [[ -f "./dotfiles" ]]; then
    rm "./dotfiles"
fi

# Build for current platform
echo -e "${BLUE}Compiling...${NC}"
if go build -ldflags "$LDFLAGS" -o dotfiles .; then
    echo -e "${GREEN}✓ Build complete: ./dotfiles${NC}"
    
    # Show binary size
    if command -v du >/dev/null 2>&1; then
        SIZE=$(du -h ./dotfiles | cut -f1)
        echo -e "  Binary size: ${YELLOW}$SIZE${NC}"
    fi
else
    echo -e "${RED}✗ Build failed${NC}" >&2
    exit 1
fi