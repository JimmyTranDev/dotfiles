#!/bin/zsh

check_tool() {
	local tool="${1:-}"
	if [[ -z "$tool" ]]; then
		print_color red "Error: No tool specified to check"
		return 1
	fi
	if ! command -v "$tool" &>/dev/null; then
		print_color red "Error: Required tool '$tool' not found."
		return 1
	fi
	return 0
}

print_color() {
	local color="${1:-white}"
	shift
	if [[ $# -gt 0 ]]; then
		print -P "%F{$color}$*%f"
	else
		print -P "%F{$color}%f"
	fi
}

slugify() {
	echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

select_fzf() {
	local prompt="$1"
	shift
	[[ $# -gt 0 ]] && printf "%s\n" "$@" | fzf --prompt="$prompt" || fzf --prompt="$prompt"
}

detect_package_manager() {
	[[ -f pnpm-lock.yaml ]] && echo "pnpm" && return
	[[ -f package-lock.json ]] && echo "npm" && return
	[[ -f yarn.lock ]] && echo "yarn" && return
	echo ""
}

get_folder_name_from_branch() {
	local branch_name="$1"

	if [[ -z "$branch_name" ]]; then
		print_color red "Error: Branch name is required"
		return 1
	fi

	if [[ "$branch_name" =~ ^[^/]+/(.+)$ ]]; then
		echo "${match[1]}"
	else
		echo "$branch_name"
	fi
}

setup_project() {
	local proj
	proj=$(select_project) || return 1

	if [[ -z "$proj" || ! -d "$PROGRAMMING_DIR/$proj" ]]; then
		print_color red "No valid project selected."
		return 1
	fi

	echo "$proj" >"$HOME/.last_project"
	echo "$PROGRAMMING_DIR/$proj"
}

select_project() {
	local last_proj_file="$HOME/.last_project"
	local last_proj=""
	[[ -f "$last_proj_file" ]] && last_proj=$(<"$last_proj_file")

	local all_projects=()
	if [[ -d "$PROGRAMMING_DIR" ]]; then
		while IFS= read -r -d '' dir; do
			all_projects+=("${dir##*/}")
		done < <(find "$PROGRAMMING_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
	fi

	if [[ ${#all_projects[@]} -eq 0 ]]; then
		print_color red "No projects found in $PROGRAMMING_DIR"
		return 1
	fi

	local projects_list=()
	if [[ -n "$last_proj" ]]; then
		for p in "${all_projects[@]}"; do
			[[ "$p" == "$last_proj" ]] && projects_list+=("$p")
		done
		for p in "${all_projects[@]}"; do
			[[ "$p" != "$last_proj" ]] && projects_list+=("$p")
		done
	else
		projects_list=("${all_projects[@]}")
	fi

	select_fzf "Select project folder: " "${projects_list[@]}"
}

install_dependencies() {
	local worktree_path="$1"

	if [[ -z "$worktree_path" || ! -d "$worktree_path" ]]; then
		print_color red "Error: Invalid worktree path"
		return 1
	fi

	cd "$worktree_path" || {
		print_color red "Error: Could not change to worktree directory"
		return 1
	}

	local pm
	pm=$(detect_package_manager)

	if [[ -n "$pm" ]]; then
		print_color cyan "Running $pm install..."
		if ! "$pm" install; then
			print_color yellow "Warning: $pm install failed"
			return 1
		fi
	else
		print_color yellow "No supported lockfile found. Skipping dependency installation."
	fi
}

find_main_branch() {
	local repo_dir="$1"

	if [[ -z "$repo_dir" || ! -d "$repo_dir" ]]; then
		print_color red "Error: Invalid repository directory"
		return 1
	fi

	local main_branch=""
	for branch in develop main master; do
		if git -C "$repo_dir" rev-parse --verify "$branch" >/dev/null 2>&1; then
			main_branch="$branch"
			break
		fi
	done

	if [[ -z "$main_branch" ]]; then
		print_color red "Error: No main branch (main/master/develop) found"
		return 1
	fi

	echo "$main_branch"
}

get_repository() {
	local repo_name="$1"
	local programming_dir="${PROGRAMMING_DIR:-$HOME/Programming}"

	local search_dirs=()
	while IFS= read -r org_dir; do
		[[ -d "$org_dir" ]] && search_dirs+=("${org_dir%/}")
	done < <(get_org_dirs "$programming_dir")
	[[ ${#search_dirs[@]} -eq 0 && -d "$programming_dir" ]] && search_dirs+=("$programming_dir")

	if [[ ${#search_dirs[@]} -eq 0 ]]; then
		print_color red "Error: No programming directories found" >&2
		return 1
	fi

	local repos=()
	local repo_labels=()
	for dir in "${search_dirs[@]}"; do
		local category=$(basename "$dir")
		while IFS= read -r -d '' git_dir; do
			local repo_path="$(dirname "$git_dir")"
			repos+=("$repo_path")
			repo_labels+=("[$category] $(basename "$repo_path")")
		done < <(find "$dir" -maxdepth 2 -name ".git" -type d -print0 2>/dev/null)
	done

	if [[ ${#repos[@]} -eq 0 ]]; then
		print_color red "No git repositories found" >&2
		return 1
	fi

	if [[ -n "$repo_name" ]]; then
		for repo in "${repos[@]}"; do
			if [[ "$(basename "$repo")" == "$repo_name" ]]; then
				echo "$repo"
				return 0
			fi
		done
		print_color red "Error: Repository '$repo_name' not found" >&2
		return 1
	fi

	print_color cyan "Scanning for git repositories..." >&2
	if check_tool fzf; then
		local selected
		selected=$(printf '%s\n' "${repo_labels[@]}" | fzf --prompt="Select repository: " --height=40% --reverse)
		[[ -z "$selected" ]] && return 1

		local selected_name="${selected##*] }"
		for repo in "${repos[@]}"; do
			if [[ "$(basename "$repo")" == "$selected_name" ]]; then
				echo "$repo"
				return 0
			fi
		done
	fi

	return 1
}
