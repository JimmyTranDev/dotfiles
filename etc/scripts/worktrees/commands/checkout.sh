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

	mkdir -p "$WORKTREES_DIR"

	local folder_name
	folder_name=$(get_folder_name_from_branch "$local_branch") || return 1

	local worktree_path="$WORKTREES_DIR/${folder_name}"

	if [[ -d "$worktree_path" ]]; then
		print_color yellow "Worktree already exists at: $worktree_path"

		if git -C "$repo_dir" worktree list | grep -q "$worktree_path"; then
			print_color green "Switching to existing worktree: $worktree_path"
			cd "$worktree_path" || {
				print_color red "Error: Could not change to worktree directory"
				return 1
			}
			print_color green "Successfully switched to worktree!"
			return 0
		else
			print_color yellow "Directory exists but is not a valid git worktree."
			print -P "%F{cyan}Options:%f"
			print -P "  1) Remove directory and create new worktree"
			print -P "  2) Cancel operation"

			local choice
			read -r "choice?Enter your choice (1-2): "

			case "$choice" in
			1)
				rm -rf "$worktree_path" || {
					print_color red "Failed to remove existing directory"
					return 1
				}
				print_color green "Removed existing directory"
				;;
			*)
				print_color yellow "Operation cancelled"
				return 0
				;;
			esac
		fi
	fi

	if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$local_branch"; then
		print_color yellow "Local branch '$local_branch' already exists. Creating worktree from existing branch."

		if ! git -C "$repo_dir" worktree add "$worktree_path" "$local_branch" 2>/dev/null; then
			if git -C "$repo_dir" worktree list | grep -q "$worktree_path"; then
				print_color yellow "Worktree is registered but missing. Cleaning up and recreating..."
				git -C "$repo_dir" worktree remove "$worktree_path" 2>/dev/null || true
			fi

			if ! git -C "$repo_dir" worktree add "$worktree_path" "$local_branch"; then
				print_color red "Failed to create worktree from existing branch."
				return 1
			fi
		fi
	else
		print_color green "Creating new branch '$local_branch' with worktree."

		if ! git -C "$repo_dir" worktree add "$worktree_path" -b "$local_branch" "origin/$local_branch" 2>/dev/null; then
			if git -C "$repo_dir" worktree list | grep -q "$worktree_path"; then
				print_color yellow "Worktree path is registered but missing. Cleaning up and recreating..."
				git -C "$repo_dir" worktree remove "$worktree_path" 2>/dev/null || true
			fi

			if ! git -C "$repo_dir" worktree add "$worktree_path" -b "$local_branch" "origin/$local_branch"; then
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
