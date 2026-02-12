#!/bin/zsh
# ===================================================================
# delete.sh - Delete Worktree Command
# ===================================================================

# Multi-select from list using fzf
select_fzf_multi() {
	local prompt="$1"
	shift
	[[ $# -gt 0 ]] && printf "%s\n" "$@" | fzf --multi --prompt="$prompt" || fzf --multi --prompt="$prompt"
}

# Delete a single worktree (extracted from main function)
delete_single_worktree() {
	local worktree_path="$1"

	# Validate worktree path is provided
	if [[ -z "$worktree_path" ]]; then
		print_color red "Error: Worktree path is required for deletion"
		return 1
	fi
	if [[ ! -d "$worktree_path" ]]; then
		print_color red "Error: Directory $worktree_path does not exist."
		return 1
	fi

	# Check if this looks like a git worktree
	if [[ ! -f "$worktree_path/.git" ]]; then
		print_color yellow "Warning: $worktree_path does not have a .git file (corrupted worktree)"
		print_color yellow "Force removing directory $worktree_path..."
		rm -rf "$worktree_path" || {
			print_color red "Error: Failed to remove directory $worktree_path"
			return 1
		}
		print_color green "✅ Successfully removed corrupted worktree directory."
		return 0
	fi

	# Detect main repo
	local gitdir_line
	gitdir_line=$(head -n1 "$worktree_path/.git")

	local worktree_gitdir
	if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
		worktree_gitdir="${match[1]}"
	else
		print_color red "Error: Could not parse .git file in $worktree_path"
		return 1
	fi

	# Get the actual repository root (not the .git directory)
	local main_repo
	main_repo=$(dirname "$(dirname "$worktree_gitdir")")
	print_color yellow "Main repo detected at: $main_repo"

	# Change to main repo directory before git operations
	cd "$main_repo" || {
		print_color red "Error: Could not change to main repo directory"
		return 1
	}

	# Detect branch name using multiple methods
	local branch_name

	print_color yellow "Attempting to detect branch name..."

	# Method 1: Try to get branch from the worktree directory itself
	if [[ -d "$worktree_path" ]]; then
		print_color yellow "Method 1: Checking branch from worktree directory"
		local old_pwd="$PWD"
		cd "$worktree_path" 2>/dev/null && {
			branch_name=$(git branch --show-current 2>/dev/null)
			if [[ -n "$branch_name" ]]; then
				print_color green "Found branch from worktree directory: $branch_name"
			fi
			cd "$old_pwd"
		}
	fi

	# Method 2: Parse git worktree list output
	if [[ -z "$branch_name" ]]; then
		print_color yellow "Method 2: Parsing git worktree list"
		local worktree_list_output
		worktree_list_output=$(git worktree list --porcelain 2>/dev/null)

		# Find the worktree entry and get the next branch line
		local found_worktree=false
		while IFS= read -r line; do
			if [[ "$line" == "worktree $worktree_path" ]]; then
				found_worktree=true
			elif [[ "$found_worktree" == true && "$line" =~ ^branch ]]; then
				branch_name=$(echo "$line" | sed 's/^branch refs\/heads\///')
				print_color green "Found branch from worktree list: $branch_name"
				break
			elif [[ "$found_worktree" == true && "$line" =~ ^worktree ]]; then
				# Hit another worktree entry, stop looking
				break
			fi
		done <<<"$worktree_list_output"
	fi

	# Method 3: Try basename matching in worktree list
	if [[ -z "$branch_name" ]]; then
		print_color yellow "Method 3: Trying basename matching"
		local worktree_basename=$(basename "$worktree_path")
		local worktree_list_output
		worktree_list_output=$(git worktree list --porcelain 2>/dev/null)

		local found_worktree=false
		while IFS= read -r line; do
			if [[ "$line" =~ worktree.*/$worktree_basename$ ]]; then
				found_worktree=true
			elif [[ "$found_worktree" == true && "$line" =~ ^branch ]]; then
				branch_name=$(echo "$line" | sed 's/^branch refs\/heads\///')
				print_color green "Found branch from basename matching: $branch_name"
				break
			elif [[ "$found_worktree" == true && "$line" =~ ^worktree ]]; then
				break
			fi
		done <<<"$worktree_list_output"
	fi

	# Method 4: Extract from directory name (last resort)
	if [[ -z "$branch_name" ]]; then
		print_color yellow "Method 4: Extracting from directory name"
		local dir_name=$(basename "$worktree_path")
		# Common patterns: BW-1234_description, feature/BW-1234, etc.
		if [[ "$dir_name" =~ ^(BW-[0-9]+) ]]; then
			branch_name="$match[1]"
			print_color yellow "Extracted branch from directory name: $branch_name"
		elif [[ "$dir_name" =~ _(.+)$ ]]; then
			# Remove prefix before underscore
			branch_name=$(echo "$dir_name" | sed 's/^[^_]*_//')
			print_color yellow "Extracted branch from directory name: $branch_name"
		fi
	fi

	if [[ -z "$branch_name" ]]; then
		print_color yellow "Could not detect branch name from git worktree list"
	else
		print_color yellow "Detected branch name: '$branch_name'"
	fi

	# Remove worktree first (regardless of branch detection)
	print_color yellow "Removing worktree: $worktree_path"
	if [[ -d "$worktree_path" ]]; then
		if git worktree remove "$worktree_path" 2>/dev/null; then
			print_color green "Successfully removed worktree: $worktree_path"
		else
			print_color yellow "Failed to remove worktree cleanly, forcing removal..."
			git worktree remove --force "$worktree_path" 2>/dev/null || true
		fi
	else
		print_color yellow "Worktree directory doesn't exist, pruning from git..."
		git worktree prune 2>/dev/null || true
	fi

	# Delete the branch if detected
	if [[ -n "$branch_name" ]]; then
		print_color yellow "Deleting branch: '$branch_name'"

		# Check if branch exists locally
		if git show-ref --verify --quiet "refs/heads/$branch_name"; then
			# Try to delete the branch
			if git branch -D "$branch_name" 2>/dev/null; then
				print_color green "✅ Successfully deleted local branch: $branch_name"
			else
				print_color red "❌ Failed to delete local branch: $branch_name"
			fi
		else
			print_color yellow "Branch '$branch_name' does not exist locally (may have been already deleted)"
		fi

		# Delete remote branch if it exists
		if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
			print_color yellow "Deleting remote branch: origin/$branch_name"
			if git push origin --delete "$branch_name" 2>/dev/null; then
				print_color green "✅ Successfully deleted remote branch: origin/$branch_name"
			else
				print_color red "❌ Failed to delete remote branch: origin/$branch_name"
			fi
		fi
	else
		print_color yellow "Could not detect branch name - no branch cleanup performed"
	fi

	# Always attempt to remove directory if it still exists
	if [[ -d "$worktree_path" ]]; then
		print_color yellow "Force removing directory $worktree_path..."
		rm -rf "$worktree_path" || true
	fi

	print_color green "✅ Worktree deletion complete."
}

# Delete worktree subcommand
cmd_delete() {
	if ! check_tool git; then
		return 1
	fi

	if ! check_tool fzf; then
		return 1
	fi

	local worktree_path="$1"

	# If no worktree path provided, allow selection
	if [[ -z "$worktree_path" ]]; then
		if [[ ! -d "$WORKTREES_DIR" ]]; then
			print_color red "Worktrees directory $WORKTREES_DIR does not exist"
			return 1
		fi

		local available_worktrees
		if [[ "$(uname)" == "Darwin" ]]; then
			available_worktrees=($(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d -exec stat -f '%B %N' {} \; | sort -rn | cut -d' ' -f2-))
		else
			available_worktrees=($(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -rn | cut -d' ' -f2-))
		fi

		if [[ ${#available_worktrees[@]} -eq 0 ]]; then
			print_color red "No worktrees found in $WORKTREES_DIR"
			return 1
		fi

		print_color cyan "Use Tab to select multiple worktrees, Enter to confirm"
		local selected_worktrees
		selected_worktrees=$(select_fzf_multi "Select worktree(s) to delete: " "${available_worktrees[@]}") || {
			print_color red "No worktrees selected."
			return 1
		}

		# Convert newline-separated list to array
		local worktrees_to_delete=()
		while IFS= read -r line; do
			[[ -n "$line" ]] && worktrees_to_delete+=("$line")
		done <<<"$selected_worktrees"

		if [[ ${#worktrees_to_delete[@]} -eq 0 ]]; then
			print_color red "No worktrees selected for deletion."
			return 1
		fi

		# Confirm deletion of multiple worktrees
		if [[ ${#worktrees_to_delete[@]} -gt 1 ]]; then
			print_color yellow "You selected ${#worktrees_to_delete[@]} worktrees for deletion:"
			for wt in "${worktrees_to_delete[@]}"; do
				print_color yellow "  - $(basename "$wt")"
			done
			print_color cyan "Are you sure you want to delete all of these? (y/N)"
			read -r confirm
			if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
				print_color yellow "Deletion cancelled."
				return 0
			fi
		fi

		# Delete each selected worktree
		local success_count=0
		local total_count=${#worktrees_to_delete[@]}

		for worktree_path in "${worktrees_to_delete[@]}"; do
			print_color cyan "Deleting worktree $(($success_count + 1))/$total_count: $(basename "$worktree_path")"
			if delete_single_worktree "$worktree_path"; then
				((success_count++))
			else
				print_color red "Failed to delete worktree: $worktree_path"
			fi
			echo # Add blank line between deletions for readability
		done

		if [[ $success_count -eq $total_count ]]; then
			print_color green "✅ Successfully deleted all $total_count worktrees."
		else
			print_color yellow "⚠️  Deleted $success_count out of $total_count worktrees."
		fi

		return 0
	else
		# Single worktree deletion (original behavior)
		delete_single_worktree "$worktree_path"
	fi
}
