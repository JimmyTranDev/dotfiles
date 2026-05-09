#!/bin/bash

set -e

main() {
	if [[ -z "$ZELLIJ" ]] && [[ -z "$TMUX" ]] && command -v zellij >/dev/null 2>&1; then
		if zellij list-sessions 2>/dev/null | grep -q .; then
			exec zellij attach
		else
			exec zellij
		fi
	else
		exec zsh
	fi
}

main "$@"
