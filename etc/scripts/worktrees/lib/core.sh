#!/bin/zsh
# ===================================================================
# core.sh - Core Worktree Utilities
# ===================================================================

# Safer version of require_tool that doesn't exit
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

# Print colored message
print_color() {
	local color="${1:-white}"
	shift
	if [[ $# -gt 0 ]]; then
		print -P "%F{$color}$*%f"
	else
		print -P "%F{$color}%f"
	fi
}

# Select from list using fzf
select_fzf() {
	local prompt="$1"
	shift
	[[ $# -gt 0 ]] && printf "%s\n" "$@" | fzf --prompt="$prompt" || fzf --prompt="$prompt"
}

# Get package manager in repo
detect_package_manager() {
	[[ -f pnpm-lock.yaml ]] && echo "pnpm" && return
	[[ -f package-lock.json ]] && echo "npm" && return
	[[ -f yarn.lock ]] && echo "yarn" && return
	echo ""
}

# Get folder name from branch name (removes prefix)
get_folder_name_from_branch() {
	local branch_name="$1"

	if [[ -z "$branch_name" ]]; then
		print_color red "Error: Branch name is required"
		return 1
	fi

	# Remove prefix (everything before and including the first slash)
	if [[ "$branch_name" =~ ^[^/]+/(.+)$ ]]; then
		echo "${match[1]}"
	else
		echo "$branch_name"
	fi
}

# Setup project and validate
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

# Select project interactively, prioritizing last used
select_project() {
	local last_proj_file="$HOME/.last_project"
	local last_proj=""
	[[ -f "$last_proj_file" ]] && last_proj=$(<"$last_proj_file")

	# Get all projects safely
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
		# Add last project first if it exists
		for p in "${all_projects[@]}"; do
			[[ "$p" == "$last_proj" ]] && projects_list+=("$p")
		done
		# Add remaining projects
		for p in "${all_projects[@]}"; do
			[[ "$p" != "$last_proj" ]] && projects_list+=("$p")
		done
	else
		projects_list=("${all_projects[@]}")
	fi

	select_fzf "Select project folder: " "${projects_list[@]}"
}

# Install dependencies if package manager detected
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

# Find main branch (prefer develop, fallback to main)
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
		print_color red "Error: No main branch (develop/main/master) found"
		return 1
	fi

	echo "$main_branch"
}

# Get repository - either by name or interactive selection
get_repository() {
	local repo_name="$1"
	local programming_dir="${PROGRAMMING_DIR:-$HOME/Programming}"

	if [[ ! -d "$programming_dir" ]]; then
		print_color red "Error: Programming directory not found: $programming_dir" >&2
		return 1
	fi

	# Build array of git repositories
	local repos=()
	while IFS= read -r -d '' git_dir; do
		repos+=("$(dirname "$git_dir")")
	done < <(find "$programming_dir" -maxdepth 2 -name ".git" -type d -print0 2>/dev/null)

	if [[ ${#repos[@]} -eq 0 ]]; then
		print_color red "No git repositories found in $programming_dir" >&2
		return 1
	fi

	# If repo name provided, find exact match
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

	# Interactive selection with fzf
	print_color cyan "Scanning for git repositories..." >&2
	if check_tool fzf; then
		local selected
		selected=$(printf '%s\n' "${repos[@]}" | xargs -n1 basename | fzf --prompt="Select repository: " --height=40% --reverse)
		[[ -z "$selected" ]] && return 1

		for repo in "${repos[@]}"; do
			if [[ "$(basename "$repo")" == "$selected" ]]; then
				echo "$repo"
				return 0
			fi
		done
	fi

	return 1
}
