#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"

get_base_branch() {
	if git rev-parse --verify develop >/dev/null 2>&1; then
		echo "develop"
	elif git rev-parse --verify main >/dev/null 2>&1; then
		echo "main"
	elif git rev-parse --verify master >/dev/null 2>&1; then
		echo "master"
	else
		log_error "No develop, main, or master branch found"
		exit 1
	fi
}

main() {
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		log_error "Not in a git repository"
		exit 1
	fi

	local current_branch
	current_branch=$(git branch --show-current)

	local base_branch
	base_branch=$(get_base_branch)

	if [[ "$current_branch" == "$base_branch" ]]; then
		log_warning "Already on $base_branch, nothing to diff"
		exit 0
	fi

	local merge_base
	merge_base=$(git merge-base "$base_branch" HEAD)

	log_info "Diffing $current_branch against $base_branch (from $(git rev-parse --short "$merge_base"))"
	echo "----------------------------------------"

	git diff "$merge_base"..HEAD "$@"
}

main "$@"
