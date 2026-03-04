#!/bin/bash

if [[ -n "$ZSH_VERSION" ]]; then
	autoload -U colors && colors
elif [[ -n "$BASH_VERSION" ]]; then
	if [[ -t 1 ]]; then
		RED='\033[0;31m'
		GREEN='\033[0;32m'
		YELLOW='\033[0;33m'
		BLUE='\033[0;34m'
		MAGENTA='\033[0;35m'
		CYAN='\033[0;36m'
		NC='\033[0m'
	fi
fi

require_tool() {
	if ! command -v "$1" &>/dev/null; then
		if [[ -n "$ZSH_VERSION" ]]; then
			print -P "%F{red}Error: Required tool '$1' not found.%f"
		else
			echo -e "${RED}Error: Required tool '$1' not found.${NC}"
		fi
		return 1
	fi
}

slugify() {
	local input="$1"
	echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
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
	local sorted_items=()

	if [[ -n "$last_sel" ]]; then
		for i in "${items[@]}"; do
			[[ "$i" == "$last_sel" ]] && sorted_items=("$i")
		done
		for i in "${items[@]}"; do
			[[ "$i" != "$last_sel" ]] && sorted_items+=("$i")
		done
	else
		sorted_items=("${items[@]}")
	fi

	local selected
	selected=$(printf "%s\n" "${sorted_items[@]}" | fzf --prompt="$prompt")
	if [[ -n "$selected" ]]; then
		echo "$selected" >"$last_file"
		local normalized_base_dir="${base_dir%/}"
		cd "$normalized_base_dir/$selected"
	else
		echo "No selection."
		return 1
	fi
}

find_git_repos() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	find "$base_dir" -maxdepth "$max_depth" -name ".git" -type d 2>/dev/null | while IFS= read -r git_dir; do
		repo_path=$(dirname "$git_dir")
		relative_path="${repo_path#$base_dir_with_slash}"
		echo "$relative_path"
	done | sort
}

find_git_worktrees() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	find "$base_dir" -maxdepth "$max_depth" -name ".git" -type f 2>/dev/null | while IFS= read -r git_file; do
		if grep -q "^gitdir:" "$git_file" 2>/dev/null; then
			worktree_path=$(dirname "$git_file")
			relative_path="${worktree_path#$base_dir_with_slash}"
			echo "$relative_path"
		fi
	done | sort
}

find_non_git_dirs() {
	local base_dir="$1"
	local max_depth="${2:-1}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	find "$base_dir" -maxdepth "$max_depth" -type d 2>/dev/null | while IFS= read -r dir; do
		[[ "$dir" == "$base_dir" ]] && continue
		if [[ ! -d "$dir/.git" && ! -f "$dir/.git" ]]; then
			relative_path="${dir#$base_dir_with_slash}"
			[[ "$relative_path" != */* ]] && echo "$relative_path"
		fi
	done | sort
}

find_git_repos_and_worktrees() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	{
		find "$base_dir" -maxdepth "$max_depth" -name ".git" -type d 2>/dev/null | while IFS= read -r git_dir; do
			repo_path=$(dirname "$git_dir")
			relative_path="${repo_path#$base_dir_with_slash}"
			echo "$relative_path"
		done

		find "$base_dir" -maxdepth "$max_depth" -name ".git" -type f 2>/dev/null | while IFS= read -r git_file; do
			if grep -q "^gitdir:" "$git_file" 2>/dev/null; then
				worktree_path=$(dirname "$git_file")
				relative_path="${worktree_path#$base_dir_with_slash}"
				echo "$relative_path"
			fi
		done
	} | sort -u
}

find_all_projects() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	{
		find_git_repos "$base_dir" "$max_depth"
		find_non_git_dirs "$base_dir" 1
	} | sort -u
}

fzf_select_and_cd() {
	local prompt="$1"
	local base_dir="$2"
	local last_file="$3"
	shift 3
	printf "%s\n" "$@" | _fzf_select_items_and_cd "$prompt" "$base_dir" "$last_file"
}

fzf_select_git_worktree_and_cd() {
	local prompt="$1"
	local base_dir="$2"
	local last_file="$3"
	local max_depth="${4:-2}"
	find_git_worktrees "$base_dir" "$max_depth" | _fzf_select_items_and_cd "$prompt" "$base_dir" "$last_file"
}

fzf_select_git_repos_and_worktrees_and_cd() {
	local prompt="$1"
	local base_dir="$2"
	local last_file="$3"
	local max_depth="${4:-2}"
	find_git_repos_and_worktrees "$base_dir" "$max_depth" | _fzf_select_items_and_cd "$prompt" "$base_dir" "$last_file"
}

fzf_select_git_repo_and_cd() {
	local prompt="$1"
	local base_dir="$2"
	local last_file="$3"
	local max_depth="${4:-2}"
	find_git_repos "$base_dir" "$max_depth" | _fzf_select_items_and_cd "$prompt" "$base_dir" "$last_file"
}

fzf_select_all_projects_and_cd() {
	local prompt="$1"
	local base_dir="$2"
	local last_file="$3"
	local max_depth="${4:-2}"
	find_all_projects "$base_dir" "$max_depth" | _fzf_select_items_and_cd "$prompt" "$base_dir" "$last_file"
}
