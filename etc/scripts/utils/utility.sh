#!/bin/bash

_UTILITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "$_UTILITY_DIR/../consts/dirs.sh"

require_tool() {
    local missing=0
    for tool in "$@"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "Error: required tool '$tool' not found" >&2
            missing=1
        fi
    done
    return $missing
}

get_org_dirs() {
	local programming_dir="${1:-$HOME/Programming}"
	for dir in "$programming_dir"/*/; do
		[[ ! -d "$dir" ]] && continue
		local name="${dir%/}"
		name="${name##*/}"
		local excluded=false
		for excl in "${PROGRAMMING_EXCLUDED_DIRS[@]}"; do
			[[ "$name" == "$excl" ]] && excluded=true && break
		done
		$excluded || echo "$dir"
	done
}

slugify() {
	local input="$1"
	echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

# Print items with last_value first (if present), then the rest in original order.
# One item per line.
reorder_last_first() {
	local last_value="$1"
	shift
	local item
	if [[ -n "$last_value" ]]; then
		for item in "$@"; do
			[[ "$item" == "$last_value" ]] && printf '%s\n' "$item"
		done
		for item in "$@"; do
			[[ "$item" != "$last_value" ]] && printf '%s\n' "$item"
		done
	else
		for item in "$@"; do
			printf '%s\n' "$item"
		done
	fi
}

_fzf_select_items_and_cd() {
	local prompt="$1"
	local base_dir="$2"
	local last_file="$3"
	shift 3
	local items=()
	while IFS= read -r line; do
		[[ -n "$line" ]] && items+=("$line")
	done

	if [[ ${#items[@]} -eq 0 ]]; then
		echo "No items found in $base_dir"
		return 1
	fi

	local last_sel=""
	[[ -f "$last_file" ]] && last_sel=$(<"$last_file")

	local selected
	selected=$(reorder_last_first "$last_sel" "${items[@]}" | fzf --prompt="$prompt")
	if [[ -n "$selected" ]]; then
		echo "$selected" >"$last_file"
		local normalized_base_dir="${base_dir%/}"
		cd "$normalized_base_dir/$selected"
	else
		echo "No selection."
		return 1
	fi
}

# Emit repo paths (dirs containing a .git directory) relative to base_dir.
_emit_git_repo_paths() {
	local base_dir="$1"
	local max_depth="$2"
	local base_dir_with_slash="$3"
	find "$base_dir" -maxdepth "$max_depth" -name ".git" -type d 2>/dev/null | while IFS= read -r git_dir; do
		repo_path=$(dirname "$git_dir")
		echo "${repo_path#$base_dir_with_slash}"
	done
}

# Emit worktree paths (dirs whose .git file points to a gitdir) relative to base_dir.
_emit_git_worktree_paths() {
	local base_dir="$1"
	local max_depth="$2"
	local base_dir_with_slash="$3"
	find "$base_dir" -maxdepth "$max_depth" -name ".git" -type f 2>/dev/null | while IFS= read -r git_file; do
		if grep -q "^gitdir:" "$git_file" 2>/dev/null; then
			worktree_path=$(dirname "$git_file")
			echo "${worktree_path#$base_dir_with_slash}"
		fi
	done
}

find_git_repos() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	_emit_git_repo_paths "$base_dir" "$max_depth" "$base_dir_with_slash" | sort
}

find_git_worktrees() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	_emit_git_worktree_paths "$base_dir" "$max_depth" "$base_dir_with_slash" | sort
}

find_git_worktrees_categorized() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	_emit_git_worktree_paths "$base_dir" "$max_depth" "$base_dir_with_slash" | while IFS= read -r relative_path; do
		if [[ "$relative_path" == /* ]]; then
			worktree_path="$relative_path"
		else
			worktree_path="${base_dir_with_slash}${relative_path}"
		fi
		if git -C "$worktree_path" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
			echo "[checkout] $relative_path"
		else
			echo "[created]  $relative_path"
		fi
	done | sort
}

get_worktree_project_name() {
	local worktree_path="${1%/}"
	local git_file="$worktree_path/.git"
	if [[ -f "$git_file" ]]; then
		local gitdir
		gitdir=$(sed -n 's/^gitdir: *//p' "$git_file" 2>/dev/null)
		if [[ -n "$gitdir" ]]; then
			local repo_root
			repo_root=$(dirname "$(dirname "$(dirname "$gitdir")")")
			basename "$repo_root"
			return 0
		fi
	fi
	echo "unknown"
}

find_git_repos_and_worktrees() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	{
		_emit_git_repo_paths "$base_dir" "$max_depth" "$base_dir_with_slash"
		_emit_git_worktree_paths "$base_dir" "$max_depth" "$base_dir_with_slash"
	} | sort -u
}
