#!/bin/bash

set -e

main() {
	if [[ -z "$ZELLIJ" ]] && [[ -z "$TMUX" ]] && command -v zellij >/dev/null 2>&1; then
		exec zellij
	else
		exec zsh
	fi
}

main "$@"
