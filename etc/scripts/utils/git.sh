#!/bin/bash

[[ -n "${_COMMON_GIT_LOADED:-}" ]] && return 0
_COMMON_GIT_LOADED=1

find_base_branch() {
	local dir="${1:-.}"

	for branch in develop main master; do
		if git -C "$dir" rev-parse --verify "$branch" &>/dev/null; then
			echo "$branch"
			return 0
		fi
	done

	echo "unknown"
	return 1
}

WORKTREE_ROOT="${WORKTREE_ROOT:-$HOME/Programming/wcreated}"

require_git_repo() {
	local dir="${1:-.}"

	if ! git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
		echo "Error: not a git repository: $dir" >&2
		return 1
	fi
}
