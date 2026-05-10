#!/bin/bash

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALL_DIR/../../utils/logging.sh"

main() {
	log_header "Starting dotfiles installation..."

	"$INSTALL_DIR/common.sh"

	if [ "$(uname)" == "Darwin" ]; then
		"$INSTALL_DIR/mac.sh"
	elif [ "$(uname)" == "Linux" ]; then
		if [ -f /etc/arch-release ]; then
			if grep -qi microsoft /proc/version 2>/dev/null; then
				"$INSTALL_DIR/wsl.sh"
			fi
			"$INSTALL_DIR/arch.sh"
		else
			log_error "Unsupported Linux distribution. Only Arch Linux is currently supported."
			exit 1
		fi
	else
		log_error "Unknown platform: $(uname)"
		exit 1
	fi

	log_success "Dotfiles installation completed successfully!"
	log_info "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
}

main "$@"
