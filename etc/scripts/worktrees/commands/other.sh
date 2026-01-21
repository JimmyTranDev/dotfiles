#!/bin/zsh
# ===================================================================
# other.sh - Clean, Rename, and Move Commands
# ===================================================================

# Clean merged/deleted branches subcommand
cmd_clean() {
	if ! check_tool git; then
		return 1
	fi

	if ! check_tool fzf; then
		return 1
	fi

	# Discover all repositories that have worktrees
	local repos_with_worktrees=()

	if [[ -d "$WORKTREES_DIR" ]]; then
		print_color yellow "Scanning for repositories with worktrees in $WORKTREES_DIR..."

		# Find all worktree directories and extract their parent repositories
		while IFS= read -r -d '' worktree_dir; do
			if [[ -f "$worktree_dir/.git" ]]; then
				local gitdir_line
				gitdir_line=$(head -n1 "$worktree_dir/.git" 2>/dev/null)
				if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
					local worktree_gitdir="${match[1]}"
					local repo_root
					repo_root=$(dirname "$(dirname "$worktree_gitdir")")
					if [[ -d "$repo_root" && ! " ${repos_with_worktrees[@]} " =~ " $repo_root " ]]; then
						repos_with_worktrees+=("$repo_root")
					fi
				fi
			fi
		done < <(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
	fi

	# If we're in a git repository, add it to the list
	if git rev-parse --git-dir >/dev/null 2>&1; then
		local current_repo
		current_repo=$(git rev-parse --show-toplevel 2>/dev/null)
		if [[ -n "$current_repo" && ! " ${repos_with_worktrees[@]} " =~ " $current_repo " ]]; then
			repos_with_worktrees+=("$current_repo")
		fi
	fi

	if [[ ${#repos_with_worktrees[@]} -eq 0 ]]; then
		print_color red "No repositories with worktrees found."
		return 1
	fi

	print_color yellow "Found ${#repos_with_worktrees[@]} repositories with worktrees:"
	for repo in "${repos_with_worktrees[@]}"; do
		print_color yellow "  $(basename "$repo") ($repo)"
	done

	# Clean all repositories with worktrees
	for repo_root in "${repos_with_worktrees[@]}"; do
		print_color cyan "===================="
		print_color cyan "Cleaning repository: $(basename "$repo_root")"
		print_color cyan "Path: $repo_root"
		print_color cyan "===================="

		local main_branch
		main_branch=$(find_main_branch "$repo_root") || {
			print_color red "Error: Could not find main branch for $(basename "$repo_root"). Skipping."
			continue
		}

		print_color yellow "Using main branch: $main_branch"
		print_color yellow "Pulling latest $main_branch..."

		if ! git -C "$repo_root" checkout "$main_branch" 2>/dev/null; then
			print_color red "Error: Failed to checkout $main_branch in $(basename "$repo_root"). Skipping."
			continue
		fi

		git -C "$repo_root" pull origin "$main_branch" || {
			print_color yellow "Warning: Failed to pull latest $main_branch"
		}

		# Get list of local branches (excluding main branch and current branch)
		local branches_to_check=()
		while IFS= read -r branch; do
			local clean_branch
			clean_branch=$(echo "$branch" | sed 's/^[* ] //')
			if [[ "$clean_branch" != "$main_branch" && "$clean_branch" != "HEAD" ]]; then
				branches_to_check+=("$clean_branch")
			fi
		done < <(git -C "$repo_root" branch --format='%(refname:short)' 2>/dev/null)

		if [[ ${#branches_to_check[@]} -eq 0 ]]; then
			print_color yellow "No branches to clean in $(basename "$repo_root")."
		else
			print_color yellow "Checking ${#branches_to_check[@]} branches for cleanup..."

			local cleaned_branches=0
			for branch in "${branches_to_check[@]}"; do
				# Check if branch is merged into main
				if git -C "$repo_root" merge-base --is-ancestor "$branch" "$main_branch" 2>/dev/null; then
					# Check if branch has been deleted on remote
					local remote_exists=false
					if git -C "$repo_root" ls-remote --heads origin "$branch" | grep -q "$branch"; then
						remote_exists=true
					fi

					# If branch is merged and either doesn't exist on remote or we want to clean merged branches
					if [[ "$remote_exists" == "false" ]]; then
						print_color yellow "  Deleting merged branch (not on remote): $branch"
						if git -C "$repo_root" branch -d "$branch" 2>/dev/null; then
							((cleaned_branches++))
						else
							print_color red "    Failed to delete branch: $branch"
						fi
					else
						# Branch exists on remote but is merged - ask user or use force flag
						print_color yellow "  Branch '$branch' is merged but exists on remote"
					fi
				else
					# Check if branch exists on remote
					if ! git -C "$repo_root" ls-remote --heads origin "$branch" | grep -q "$branch"; then
						print_color yellow "  Branch '$branch' not found on remote (may be safe to delete)"
						print_color yellow "  Use 'git branch -D $branch' to force delete if needed"
					fi
				fi
			done

			if [[ $cleaned_branches -gt 0 ]]; then
				print_color green "  Cleaned $cleaned_branches branches"
			else
				print_color yellow "  No branches were automatically cleaned"
			fi
		fi

		# Clean up worktree references for deleted worktrees
		print_color yellow "Cleaning up stale worktree references..."
		git -C "$repo_root" worktree prune 2>/dev/null || true

		print_color green "Done cleaning $(basename "$repo_root")."
	done

	print_color green "✅ Finished cleaning all repositories with worktrees."
}

# Rename current branch subcommand
cmd_rename() {
	if ! check_tool git; then
		return 1
	fi

	local repo_root
	repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
		print_color red "Error: Not in a git repository"
		return 1
	}

	local current_branch
	current_branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
		print_color red "Error: Could not determine current branch"
		return 1
	}

	print_color cyan "Current branch: $current_branch"

	# Check if branch already contains JIRA ticket
	if [[ "$current_branch" =~ $JIRA_PATTERN ]]; then
		if ! check_tool acli; then
			print_color red "acli not available. Cannot fetch ticket details."
			return 1
		fi

		local jira_ticket
		jira_ticket=$(echo "$current_branch" | grep -oE "$JIRA_PATTERN")
		print_color yellow "Branch already contains JIRA ticket: $jira_ticket"
		print_color yellow "Fetching summary via acli..."

		local summary
		summary=$(get_jira_summary "$jira_ticket" 2>/dev/null)
		if [[ $? -eq 0 && -n "$summary" ]]; then
			local clean_summary
			clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
			local new_branch="${jira_ticket}-${clean_summary}"

			if [[ "$current_branch" == "$new_branch" ]]; then
				print_color green "Branch name already matches desired format. No changes made."
				return 0
			fi

			git -C "$repo_root" branch -m "$new_branch" || {
				print_color red "Failed to rename branch"
				return 1
			}

			print_color green "Branch renamed to: $new_branch"
			return 0
		else
			print_color red "Could not fetch summary. No changes made."
			return 1
		fi
	fi

	# Get user input for new branch name
	print_color cyan "Enter new branch name or JIRA ticket (e.g., ABC-123): "
	read -r input

	if [[ -z "$input" ]]; then
		print_color red "No input provided. Aborting."
		return 1
	fi

	local new_branch="$input"

	# Check if input is a JIRA ticket
	if [[ "$input" =~ $JIRA_PATTERN ]]; then
		if ! check_tool acli; then
			print_color yellow "acli not available. Using input as branch name without JIRA integration."
			new_branch="$input"
		else
			print_color yellow "JIRA ticket detected. Fetching summary via acli..."

			local summary
			summary=$(get_jira_summary "$input" 2>/dev/null)
			if [[ $? -eq 0 && -n "$summary" ]]; then
				local clean_summary
				clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
				new_branch="${input}-${clean_summary}"
			else
				print_color yellow "Could not fetch JIRA summary. Using ticket number as branch name."
				new_branch="$input"
			fi
		fi
	fi

	git -C "$repo_root" branch -m "$new_branch" || {
		print_color red "Failed to rename branch"
		return 1
	}

	print_color green "Branch renamed to: $new_branch"
}

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
