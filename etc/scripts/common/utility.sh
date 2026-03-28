#!/bin/bash

PROGRAMMING_EXCLUDED_DIRS=("Worktrees" "wcreated" "wcheckout" "secrets")

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

find_git_worktrees_categorized() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	find "$base_dir" -maxdepth "$max_depth" -name ".git" -type f 2>/dev/null | while IFS= read -r git_file; do
		if grep -q "^gitdir:" "$git_file" 2>/dev/null; then
			worktree_path=$(dirname "$git_file")
			relative_path="${worktree_path#$base_dir_with_slash}"
			if git -C "$worktree_path" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
				echo "[checkout] $relative_path"
			else
				echo "[created]  $relative_path"
			fi
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
