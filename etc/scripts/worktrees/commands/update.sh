#!/bin/zsh

cmd_update() {
	print_color yellow "Updating all worktrees in $WORKTREES_DIR..."

	if [[ ! -d "$WORKTREES_DIR" ]]; then
		print_color red "Error: Worktrees directory $WORKTREES_DIR does not exist"
		return 1
	fi

	local updated_count=0
	local failed_count=0
	local skipped_count=0

	while IFS= read -r -d '' worktree_path; do
		local worktree_name="${worktree_path##*/}"

		print_color cyan "\n--- Processing worktree: $worktree_name ---"

		if [[ ! -f "$worktree_path/.git" ]]; then
			print_color yellow "Skipping $worktree_name: Not a git worktree"
			((skipped_count++))
			continue
		fi

		local current_branch
		current_branch=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
			print_color red "Error: Failed to get current branch for $worktree_name"
			((failed_count++))
			continue
		}

		if [[ "$current_branch" == "HEAD" ]]; then
			print_color yellow "Skipping $worktree_name: In detached HEAD state"
			((skipped_count++))
			continue
		fi

		print_color blue "Current branch: $current_branch"

		if ! git -C "$worktree_path" diff-index --quiet HEAD -- 2>/dev/null; then
			print_color yellow "Warning: $worktree_name has uncommitted changes, skipping..."
			((skipped_count++))
			continue
		fi

		local remote_branch
		remote_branch=$(git -C "$worktree_path" rev-parse --abbrev-ref @{u} 2>/dev/null) || {
			print_color yellow "Skipping $worktree_name: No remote tracking branch for $current_branch"
			((skipped_count++))
			continue
		}

		print_color blue "Remote branch: $remote_branch"

		print_color blue "Fetching latest changes..."
		if ! git -C "$worktree_path" fetch origin 2>/dev/null; then
			print_color red "Error: Failed to fetch for $worktree_name"
			((failed_count++))
			continue
		fi

		local local_commit remote_commit
		local_commit=$(git -C "$worktree_path" rev-parse HEAD)
		remote_commit=$(git -C "$worktree_path" rev-parse @{u})

		if [[ "$local_commit" == "$remote_commit" ]]; then
			print_color green "Already up to date: $worktree_name"
			((updated_count++))
			continue
		fi

		print_color blue "Pulling with rebase..."
		if git -C "$worktree_path" pull --rebase origin "$current_branch" 2>/dev/null; then
			print_color green "Successfully updated: $worktree_name"
			((updated_count++))
		else
			print_color red "Error: Failed to pull and rebase $worktree_name"
			((failed_count++))

			local git_common_dir
			git_common_dir=$(git -C "$worktree_path" rev-parse --git-dir 2>/dev/null)
			if [[ -d "$git_common_dir/rebase-merge" ]] || [[ -d "$git_common_dir/rebase-apply" ]]; then
				print_color yellow "Aborting rebase for $worktree_name..."
				git -C "$worktree_path" rebase --abort 2>/dev/null || true
			fi
		fi

	done < <(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

	print_color yellow "\n=== Update Summary ==="
	print_color green "Updated: $updated_count"
	print_color yellow "Skipped: $skipped_count"
	print_color red "Failed: $failed_count"

	if [[ $failed_count -gt 0 ]]; then
		print_color red "\nSome worktrees failed to update. Please check them manually."
		return 1
	else
		print_color green "\nAll worktrees processed successfully!"
		return 0
	fi
}
