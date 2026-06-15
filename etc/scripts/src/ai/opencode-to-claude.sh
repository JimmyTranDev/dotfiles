#!/bin/bash
set -e

# Thin wrapper around opencode-to-claude.mjs. Generates a Claude Code config
# (CLAUDE.md, agents/, commands/, skills/, settings.json) from the OpenCode
# config. OpenCode is the single source of truth; the output is regenerated and
# must never be hand-edited.
# See architecture/0001-claude-config-generated-from-opencode.md.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "$SCRIPT_DIR/../../utils/logging.sh"

if ! command -v node &>/dev/null; then
	log_error "node not found - required to run the converter"
	exit 1
fi

# Run from the dotfiles root so the default src/opencode and src/claude paths
# resolve regardless of the caller's working directory. Explicit path arguments
# still override the defaults.
cd "$DOTFILES_ROOT"
exec node "$SCRIPT_DIR/opencode-to-claude.mjs" "$@"
