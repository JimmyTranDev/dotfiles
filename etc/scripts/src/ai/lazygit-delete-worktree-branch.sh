#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

# Resolve the main worktree path (the parent of the shared .git common dir).
# Works from inside any linked worktree of the repo. Echoes empty on failure.
get_main_worktree() {
	local common_dir
	common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "")
	if [[ -z "$common_dir" ]]; then
		return 0
	fi
	dirname "$common_dir"
	return 0
}

# Echo the branch checked out at a given worktree path (empty if detached/none).
branch_for_worktree_path() {
	local target="${1%/}"
	local line current=""
	while IFS= read -r line; do
		if [[ "$line" == "worktree "* ]]; then
			current="${line#worktree }"
		elif [[ "$line" == "branch refs/heads/"* && "${current%/}" == "$target" ]]; then
			echo "${line#branch refs/heads/}"
			return 0
		fi
	done < <(git worktree list --porcelain 2>/dev/null)
	return 0
}

# Echo the worktree path that has a given branch checked out (empty if none).
worktree_path_for_branch() {
	local branch="$1"
	local line current=""
	while IFS= read -r line; do
		if [[ "$line" == "worktree "* ]]; then
			current="${line#worktree }"
		elif [[ "$line" == "branch refs/heads/$branch" ]]; then
			echo "$current"
			return 0
		fi
	done < <(git worktree list --porcelain 2>/dev/null)
	return 0
}

# Guard a directory before `rm -rf`: canonicalize it (resolving symlinks and
# '..') then refuse catastrophic targets — empty, '/', $HOME, the main worktree
# itself, or any ancestor of the main worktree (removing which would take the
# repo down). Returns 0 only when the path is safe to delete.
is_safe_to_remove() {
	local path="$1"
	local main_worktree="$2"

	if [[ -z "$path" || ! -d "$path" ]]; then
		return 1
	fi

	local real_path real_main
	real_path=$(cd "$path" 2>/dev/null && pwd -P) || return 1
	real_main=$(cd "$main_worktree" 2>/dev/null && pwd -P) || real_main="${main_worktree%/}"

	if [[ -z "$real_path" || "$real_path" == "/" || "$real_path" == "$HOME" ]]; then
		return 1
	fi
	if [[ "$real_path" == "$real_main" ]]; then
		return 1
	fi
	# Refuse if the main worktree lives inside $real_path (i.e. path is an ancestor).
	if [[ "$real_main" == "$real_path"/* ]]; then
		return 1
	fi
	return 0
}

# Remove the worktree at $path. Never touches the main worktree. Sets
# RESULT_WORKTREE to one of: none, skipped_main, removed, pruned.
remove_worktree() {
	local main_worktree="$1"
	local path="$2"

	if [[ -z "$path" ]]; then
		RESULT_WORKTREE="none"
		return 0
	fi

	if [[ "${path%/}" == "${main_worktree%/}" ]]; then
		log_warning "Refusing to remove the main worktree: $path"
		RESULT_WORKTREE="skipped_main"
		return 0
	fi

	log_info "Removing worktree: $path"
	if git -C "$main_worktree" worktree remove --force "$path" 2>/dev/null; then
		log_success "Removed worktree: $path"
		RESULT_WORKTREE="removed"
	else
		# Worktree already gone or never registered — drop any leftover
		# directory so the path can't block re-creation; prune handles git's metadata.
		log_warning "Could not remove via git (already gone or unregistered); cleaning up"
		if is_safe_to_remove "$path" "$main_worktree"; then
			rm -rf "$path" 2>/dev/null || true
		elif [[ -d "$path" ]]; then
			log_error "Refusing to rm -rf unsafe path: $path"
		fi
		RESULT_WORKTREE="pruned"
	fi
	return 0
}

# Force-delete the local branch. Refuses the current HEAD (git would reject it).
# Sets RESULT_BRANCH to one of: none, current_head, not_found, deleted, failed.
delete_branch() {
	local main_worktree="$1"
	local branch="$2"

	if [[ -z "$branch" ]]; then
		RESULT_BRANCH="none"
		return 0
	fi

	local current
	current=$(git -C "$main_worktree" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
	if [[ "$branch" == "$current" ]]; then
		log_error "Cannot delete '$branch': it is the current HEAD of the main worktree"
		RESULT_BRANCH="current_head"
		return 0
	fi

	if ! git -C "$main_worktree" show-ref --verify --quiet "refs/heads/$branch"; then
		log_warning "Branch not found locally: $branch"
		RESULT_BRANCH="not_found"
		return 0
	fi

	log_info "Deleting branch: $branch"
	if git -C "$main_worktree" branch -D "$branch" 2>/dev/null; then
		log_success "Deleted branch: $branch"
		RESULT_BRANCH="deleted"
	else
		log_error "Failed to delete branch: $branch"
		RESULT_BRANCH="failed"
	fi
	return 0
}

delete_worktree_and_branch() {
	local path="$1"
	local branch="$2"

	local main_worktree
	main_worktree=$(get_main_worktree)
	if [[ -z "$main_worktree" ]]; then
		log_error "Not inside a git repository"
		return 1
	fi

	# Cross-fill whichever of path/branch was not supplied so a single
	# invocation works from either the worktrees or localBranches context.
	if [[ -n "$path" && -z "$branch" ]]; then
		branch=$(branch_for_worktree_path "$path")
	fi
	if [[ -z "$path" && -n "$branch" ]]; then
		path=$(worktree_path_for_branch "$branch")
	fi

	# Order matters: the worktree must go first, otherwise git refuses to
	# delete a branch that is still checked out somewhere.
	remove_worktree "$main_worktree" "$path"
	delete_branch "$main_worktree" "$branch"

	log_info "Pruning stale worktree metadata"
	git -C "$main_worktree" worktree prune 2>/dev/null || true

	json_output "$(json_obj_raw \
		"worktree_path" "$(json_escape "$path")" \
		"branch" "$(json_escape "$branch")" \
		"worktree_result" "$(json_escape "$RESULT_WORKTREE")" \
		"branch_result" "$(json_escape "$RESULT_BRANCH")" \
		"pruned" "true")"
	return 0
}

show_help() {
	cat <<'EOF' >&2
Usage: lazygit-delete-worktree-branch.sh [--path <worktree-path>] [--branch <branch-name>]

Remove a git worktree and delete its branch in the correct order so the
operation succeeds in a single pass: remove the worktree (force), then
force-delete the branch, then prune stale worktree metadata.

At least one of --path or --branch is required. The missing one is derived
from `git worktree list`, so this works whether it is triggered from the
worktrees view (path known) or the local branches view (branch known).

Options:
  --path <worktree-path>   Path of the worktree to remove
  --branch <branch-name>   Branch to force-delete
  --help                   Show this help message
EOF
}

main() {
	local path=""
	local branch=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		--path)
			path="$2"
			shift 2
			;;
		--branch)
			branch="$2"
			shift 2
			;;
		*)
			log_error "Unknown option: $1"
			show_help
			exit 1
			;;
		esac
	done

	if [[ -z "$path" && -z "$branch" ]]; then
		log_error "Provide at least one of --path or --branch"
		show_help
		exit 1
	fi

	require_command "git" "https://git-scm.com/downloads"
	delete_worktree_and_branch "$path" "$branch"
}

main "$@"
