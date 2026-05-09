#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

get_commits() {
	git log --oneline -n 50 --pretty=format:"%h %s"
}

main() {
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		log_error "Not in a git repository"
		exit 1
	fi

	if ! command -v fzf &>/dev/null; then
		log_error "fzf is required but not installed"
		exit 1
	fi

	log_info "Select commit:"
	local commit
	commit=$(get_commits | fzf --height=20 --reverse --prompt="Commit > " | awk '{print $1}')

	if [[ -z "$commit" ]]; then
		log_warning "No commit selected"
		exit 1
	fi

	echo ""
	log_info "Showing diff for $commit"
	echo "----------------------------------------"

	git show "$commit"
}

main "$@"
