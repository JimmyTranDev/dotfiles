#!/bin/zsh
# ===================================================================
# clean.sh - Clean Worktrees and Merged Branches
# ===================================================================

# Clean worktrees and delete merged branches
cmd_clean_worktrees() {
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
	local total_worktrees_deleted=0
	local total_branches_deleted=0

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

		# Get all worktrees for this repository (excluding main worktree)
		local repo_worktrees=()
		local worktree_branches=()

		while IFS= read -r line; do
			if [[ "$line" =~ ^worktree ]]; then
				local wt_path="${line#worktree }"
				# Skip the main repository worktree
				if [[ "$wt_path" != "$repo_root" ]]; then
					repo_worktrees+=("$wt_path")
				fi
			elif [[ "$line" =~ ^branch ]]; then
				local branch_name="${line#branch refs/heads/}"
				if [[ ${#repo_worktrees[@]} -gt ${#worktree_branches[@]} ]]; then
					worktree_branches+=("$branch_name")
				fi
			fi
		done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null)

		if [[ ${#repo_worktrees[@]} -eq 0 ]]; then
			print_color yellow "No worktrees found for $(basename "$repo_root")."
		else
			print_color yellow "Found ${#repo_worktrees[@]} worktrees to check..."

			local repo_deleted_worktrees=0
			local repo_deleted_branches=0

			for i in {1..${#repo_worktrees[@]}}; do
				local wt_path="${repo_worktrees[$i]}"
				local branch_name="${worktree_branches[$i]}"

				if [[ -z "$branch_name" ]]; then
					print_color yellow "  Skipping worktree without branch: $wt_path"
					continue
				fi

				# Check if branch is merged into main
				if git -C "$repo_root" merge-base --is-ancestor "$branch_name" "$main_branch" 2>/dev/null; then
					print_color yellow "  Branch '$branch_name' is merged into $main_branch"

					# Remove worktree
					print_color yellow "  Removing worktree: $wt_path"
					if [[ -d "$wt_path" ]]; then
						if git -C "$repo_root" worktree remove "$wt_path" 2>/dev/null; then
							print_color green "    ✓ Worktree removed"
							((repo_deleted_worktrees++))
						else
							print_color yellow "    Forcing worktree removal..."
							git -C "$repo_root" worktree remove --force "$wt_path" 2>/dev/null || true
							if [[ ! -d "$wt_path" ]]; then
								print_color green "    ✓ Worktree force removed"
								((repo_deleted_worktrees++))
							fi
						fi
					fi

					# Force remove directory if it still exists
					if [[ -d "$wt_path" ]]; then
						print_color yellow "    Force removing directory..."
						rm -rf "$wt_path" || true
					fi

					# Delete the branch
					print_color yellow "  Deleting branch: $branch_name"
					if git -C "$repo_root" branch -d "$branch_name" 2>/dev/null; then
						print_color green "    ✓ Branch deleted"
						((repo_deleted_branches++))
					else
						print_color yellow "    Branch has unmerged changes, forcing deletion..."
						if git -C "$repo_root" branch -D "$branch_name" 2>/dev/null; then
							print_color green "    ✓ Branch force deleted"
							((repo_deleted_branches++))
						else
							print_color red "    ✗ Failed to delete branch"
						fi
					fi
				else
					print_color yellow "  Branch '$branch_name' is NOT merged into $main_branch - skipping"
				fi
			done

			print_color green "Repository summary:"
			print_color green "  Worktrees deleted: $repo_deleted_worktrees"
			print_color green "  Branches deleted: $repo_deleted_branches"

			total_worktrees_deleted=$((total_worktrees_deleted + repo_deleted_worktrees))
			total_branches_deleted=$((total_branches_deleted + repo_deleted_branches))
		fi

		# Clean up stale worktree references
		print_color yellow "Cleaning up stale worktree references..."
		git -C "$repo_root" worktree prune 2>/dev/null || true

		print_color green "Done cleaning $(basename "$repo_root")."
		echo
	done

	print_color green "===================="
	print_color green "✅ Cleanup Complete"
	print_color green "===================="
	print_color green "Total worktrees deleted: $total_worktrees_deleted"
	print_color green "Total branches deleted: $total_branches_deleted"
}
