#!/bin/zsh

cmd_checkout() {
	if ! check_tool git; then
		return 1
	fi

	if ! check_tool fzf; then
		return 1
	fi

	local repo_dir
	repo_dir=$(setup_project) || return 1

	git -C "$repo_dir" fetch origin || {
		print_color red "Failed to fetch from origin"
		return 1
	}

	local all_remote_branches=()
	while IFS= read -r branch; do
		[[ -n "$branch" ]] && all_remote_branches+=("$branch")
	done < <(git -C "$repo_dir" branch -r | grep '^  origin/' | sed 's/^  origin\///' | grep -vE '^HEAD$' | sort)

	if [[ ${#all_remote_branches[@]} -eq 0 ]]; then
		print_color red "No remote branches found"
		return 1
	fi

	local branch_sel
	branch_sel=$(select_fzf "Select remote branch to checkout: " "${all_remote_branches[@]}") || {
		print_color red "No branch selected."
		return 1
	}

	local local_branch="$branch_sel"

	mkdir -p "$WCHECKOUT_DIR"

	local folder_name
	folder_name=$(get_folder_name_from_branch "$local_branch") || return 1

	local worktree_path
	worktree_path=$(resolve_unique_dir "$WCHECKOUT_DIR/${folder_name}")

	local actual_branch="$local_branch"
	if [[ "$worktree_path" != "$WCHECKOUT_DIR/${folder_name}" ]]; then
		actual_branch="${local_branch}-$(basename "$worktree_path" | grep -o '[0-9]*$')"
	fi

	if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$actual_branch"; then
		print_color yellow "Local branch '$actual_branch' already exists. Creating worktree from existing branch."

		if ! git -C "$repo_dir" worktree add "$worktree_path" "$actual_branch" 2>/dev/null; then
			if git -C "$repo_dir" worktree list | grep -q "$worktree_path"; then
				print_color yellow "Worktree is registered but missing. Cleaning up and recreating..."
				git -C "$repo_dir" worktree remove "$worktree_path" 2>/dev/null || true
			fi

			if ! git -C "$repo_dir" worktree add "$worktree_path" "$actual_branch"; then
				print_color red "Failed to create worktree from existing branch."
				return 1
			fi
		fi
	else
		print_color green "Creating new branch '$actual_branch' with worktree."

		if ! git -C "$repo_dir" worktree add "$worktree_path" -b "$actual_branch" "origin/$local_branch" 2>/dev/null; then
			if git -C "$repo_dir" worktree list | grep -q "$worktree_path"; then
				print_color yellow "Worktree path is registered but missing. Cleaning up and recreating..."
				git -C "$repo_dir" worktree remove "$worktree_path" 2>/dev/null || true
			fi

			if ! git -C "$repo_dir" worktree add "$worktree_path" -b "$actual_branch" "origin/$local_branch"; then
				print_color red "Failed to create worktree with new branch."
				return 1
			fi
		fi
	fi

	print_color green "Worktree created at: $worktree_path"

	install_dependencies "$worktree_path"

	cd "$worktree_path" || {
		print_color yellow "Warning: Could not navigate to worktree directory"
	}

	print_color green "Checkout completed successfully!"
}
