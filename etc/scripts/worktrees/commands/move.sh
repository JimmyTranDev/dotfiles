#!/bin/zsh
# ===================================================================
# move.sh - Move Worktree Command
# ===================================================================

# Move worktree subcommand
cmd_move() {
	if ! check_tool git; then
		return 1
	fi

	if ! check_tool fzf; then
		return 1
	fi

	local source_path="$1"
	local dest_path="$2"

	# Select source worktree if not provided
	if [[ -z "$source_path" ]]; then
		if [[ ! -d "$WORKTREES_DIR" ]]; then
			print_color red "Worktrees directory $WORKTREES_DIR does not exist"
			return 1
		fi

		local available_worktrees
		available_worktrees=($(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d | sort))

		if [[ ${#available_worktrees[@]} -eq 0 ]]; then
			print_color red "No worktrees found in $WORKTREES_DIR"
			return 1
		fi

		source_path=$(select_fzf "Select a worktree to move: " "${available_worktrees[@]}") || {
			print_color red "No worktree selected."
			return 1
		}
	fi

	# Validate source worktree
	if [[ ! -d "$source_path" ]]; then
		print_color red "Error: Directory $source_path does not exist."
		return 1
	fi

	if [[ ! -f "$source_path/.git" ]]; then
		print_color red "Error: $source_path does not look like a git worktree (missing .git file)."
		return 1
	fi

	# Get destination path if not provided
	if [[ -z "$dest_path" ]]; then
		local worktree_name
		worktree_name=$(basename "$source_path")

		print_color cyan "Enter new location for worktree '$worktree_name':"
		print_color yellow "Current location: $source_path"
		print_color yellow "Enter full path or just new parent directory:"
		read dest_path

		if [[ -z "$dest_path" ]]; then
			print_color red "No destination path provided."
			return 1
		fi

		# If dest_path is just a directory, append the worktree name
		if [[ -d "$dest_path" ]]; then
			dest_path="$dest_path/$worktree_name"
		fi
	fi

	# Validate destination
	if [[ -e "$dest_path" ]]; then
		print_color red "Error: Destination $dest_path already exists."
		return 1
	fi

	# Detect main repo
	local gitdir_line worktree_gitdir main_repo
	gitdir_line=$(head -n1 "$source_path/.git")

	if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
		worktree_gitdir="${match[1]}"
	else
		print_color red "Error: Could not parse .git file in $source_path"
		return 1
	fi

	main_repo=$(dirname "$(dirname "$worktree_gitdir")")

	print_color yellow "Moving worktree from $source_path to $dest_path..."

	# Use git worktree move command
	git -C "$main_repo" worktree move "$source_path" "$dest_path" || {
		print_color red "Error: Failed to move worktree. Check that Git version supports 'git worktree move' (Git 2.17+)"
		return 1
	}

	print_color green "Successfully moved worktree to: $dest_path"
	print_color cyan "You can now access the worktree at the new location."
}
