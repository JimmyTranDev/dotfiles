#!/bin/zsh

is_wcreated_worktree() {
	local worktree_path="$1"
	local resolved_wt="${worktree_path:A}"
	local resolved_created="${WCREATED_DIR:A}"
	[[ "$resolved_wt" == "$resolved_created"/* ]]
}

delete_single_worktree() {
	local worktree_path="$1"
	local original_dir="$PWD"

	if [[ -z "$worktree_path" ]]; then
		print_color red "Error: Worktree path is required for deletion"
		return 1
	fi
	if [[ ! -d "$worktree_path" ]]; then
		print_color red "Error: Directory $worktree_path does not exist."
		return 1
	fi

	local delete_remote=false
	if is_wcreated_worktree "$worktree_path"; then
		delete_remote=true
	fi

	if [[ ! -f "$worktree_path/.git" ]]; then
		print_color yellow "Warning: $worktree_path does not have a .git file (corrupted worktree)"
		print_color yellow "Force removing directory $worktree_path..."
		rm -rf "$worktree_path" || {
			print_color red "Error: Failed to remove directory $worktree_path"
			return 1
		}
		print_color green "Successfully removed corrupted worktree directory."
		return 0
	fi

	local main_repo
	main_repo=$(resolve_main_repo_from_worktree "$worktree_path") || {
		print_color red "Error: Could not parse .git file in $worktree_path"
		return 1
	}
	print_color yellow "Main repo detected at: $main_repo"

	cd "$main_repo" || {
		print_color red "Error: Could not change to main repo directory"
		return 1
	}

	local branch_name

	print_color yellow "Attempting to detect branch name..."

	if [[ -d "$worktree_path" ]]; then
		local old_pwd="$PWD"
		cd "$worktree_path" 2>/dev/null && {
			branch_name=$(git branch --show-current 2>/dev/null)
			if [[ -n "$branch_name" ]]; then
				print_color green "Found branch from worktree directory: $branch_name"
			fi
			cd "$old_pwd"
		}
	fi

	if [[ -z "$branch_name" ]]; then
		branch_name=$(worktree_branch_from_porcelain "$main_repo" "$worktree_path" exact)
		if [[ -n "$branch_name" ]]; then
			print_color green "Found branch from worktree list: $branch_name"
		fi
	fi

	if [[ -z "$branch_name" ]]; then
		local worktree_basename=$(basename "$worktree_path")
		branch_name=$(worktree_branch_from_porcelain "$main_repo" "$worktree_basename" basename)
		if [[ -n "$branch_name" ]]; then
			print_color green "Found branch from basename matching: $branch_name"
		fi
	fi

	if [[ -z "$branch_name" ]]; then
		local dir_name=$(basename "$worktree_path")
		if [[ "$dir_name" =~ ^([A-Z]+-[0-9]+) ]]; then
			branch_name="$match[1]"
			print_color yellow "Extracted branch from directory name: $branch_name"
		elif [[ "$dir_name" =~ _(.+)$ ]]; then
			branch_name=$(echo "$dir_name" | sed 's/^[^_]*_//')
			print_color yellow "Extracted branch from directory name: $branch_name"
		fi
	fi

	if [[ -z "$branch_name" ]]; then
		print_color yellow "Could not detect branch name from git worktree list"
	else
		print_color yellow "Detected branch name: '$branch_name'"
	fi

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

	if [[ -n "$branch_name" ]]; then
		print_color yellow "Deleting branch: '$branch_name'"

		if git show-ref --verify --quiet "refs/heads/$branch_name"; then
			if git branch -D "$branch_name" 2>/dev/null; then
				print_color green "Successfully deleted local branch: $branch_name"
			else
				print_color red "Failed to delete local branch: $branch_name"
			fi
		else
			print_color yellow "Branch '$branch_name' does not exist locally (may have been already deleted)"
		fi

		if [[ "$delete_remote" == true ]]; then
			if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
				print_color yellow "Deleting remote branch origin/$branch_name (created worktree)..."
				if git push origin --delete "$branch_name" 2>/dev/null; then
					print_color green "Successfully deleted remote branch: origin/$branch_name"
				else
					print_color red "Failed to delete remote branch: origin/$branch_name"
				fi
			fi
		else
			print_color yellow "Skipping remote branch deletion (checkout worktree)."
		fi
	else
		print_color yellow "Could not detect branch name - no branch cleanup performed"
	fi

	if [[ -d "$worktree_path" ]]; then
		print_color yellow "Force removing directory $worktree_path..."
		rm -rf "$worktree_path" || true
	fi

	print_color green "Worktree deletion complete."
	cd "$original_dir" 2>/dev/null || true
}

collect_worktrees_from_dirs() {
	local dirs=("$WCREATED_DIR" "$WCHECKOUT_DIR")
	for dir in "${dirs[@]}"; do
		[[ ! -d "$dir" ]] && continue
		if [[ "$(uname)" == "Darwin" ]]; then
			find "$dir" -mindepth 1 -maxdepth 1 -type d -exec stat -f '%B %N' {} \; 2>/dev/null
		else
			find "$dir" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null
		fi
	done | sort -rn | cut -d' ' -f2-
}

cmd_delete() {
	if ! check_tool git; then
		return 1
	fi

	if ! check_tool fzf; then
		return 1
	fi

	local worktree_path="$1"

	if [[ -z "$worktree_path" ]]; then
		local available_worktrees=()
		while IFS= read -r line; do
			[[ -n "$line" ]] && available_worktrees+=("$line")
		done < <(collect_worktrees_from_dirs)

		if [[ ${#available_worktrees[@]} -eq 0 ]]; then
			print_color red "No worktrees found"
			return 1
		fi

		local labels=()
		local wt_name project_name label
		typeset -A label_to_path
		for wt in "${available_worktrees[@]}"; do
			wt_name="${wt##*/}"
			project_name=$(get_worktree_project_name "$wt")
			label="[$project_name] $wt_name"
			labels+=("$label")
			label_to_path[$label]="$wt"
		done

		print_color cyan "Use Tab to select multiple worktrees, Enter to confirm"
		local selected_labels
		selected_labels=$(select_fzf_multi "Select worktree(s) to delete: " "${labels[@]}") || {
			print_color red "No worktrees selected."
			return 1
		}

		local worktrees_to_delete=()
		while IFS= read -r line; do
			[[ -n "$line" ]] && worktrees_to_delete+=("${label_to_path[$line]}")
		done <<<"$selected_labels"

		if [[ ${#worktrees_to_delete[@]} -eq 0 ]]; then
			print_color red "No worktrees selected for deletion."
			return 1
		fi

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

		local total_count=${#worktrees_to_delete[@]}
		local success_count=0
		typeset -A remote_branches_by_repo

		local wt_path should_delete_remote main_repo branch_name old_pwd repo_key
		for i in {1..$total_count}; do
			wt_path="${worktrees_to_delete[$i]}"
			print_color cyan "Worktree $i/$total_count: $(basename "$wt_path")"

			should_delete_remote=false
			if is_wcreated_worktree "$wt_path"; then
				should_delete_remote=true
			fi

			if [[ ! -d "$wt_path" ]]; then
				print_color yellow "Worktree directory doesn't exist, skipping."
				continue
			fi

			if [[ ! -f "$wt_path/.git" ]]; then
				print_color yellow "Warning: corrupted worktree, force removing..."
				rm -rf "$wt_path" || true
				((success_count++))
				continue
			fi

			main_repo=$(resolve_main_repo_from_worktree "$wt_path") || {
				print_color red "Error: Could not parse .git file in $wt_path"
				continue
			}

			branch_name=""
			old_pwd="$PWD"
			cd "$wt_path" 2>/dev/null && {
				branch_name=$(git branch --show-current 2>/dev/null)
				cd "$old_pwd"
			}

			if [[ -z "$branch_name" ]]; then
				branch_name=$(worktree_branch_from_porcelain "$main_repo" "$wt_path" exact)
			fi

			cd "$main_repo" 2>/dev/null || continue

			print_color yellow "Removing worktree: $wt_path"
			if git worktree remove "$wt_path" 2>/dev/null; then
				print_color green "Successfully removed worktree: $wt_path"
			else
				git worktree remove --force "$wt_path" 2>/dev/null || true
			fi

			if [[ -n "$branch_name" ]]; then
				if git show-ref --verify --quiet "refs/heads/$branch_name"; then
					if git branch -D "$branch_name" 2>/dev/null; then
						print_color green "Deleted local branch: $branch_name"
					fi
				fi

				if [[ "$should_delete_remote" == true ]]; then
					if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
						repo_key="${main_repo}"
						if [[ -n "${remote_branches_by_repo[$repo_key]}" ]]; then
							remote_branches_by_repo[$repo_key]="${remote_branches_by_repo[$repo_key]} $branch_name"
						else
							remote_branches_by_repo[$repo_key]="$branch_name"
						fi
					fi
				fi
			fi

			if [[ -d "$wt_path" ]]; then
				rm -rf "$wt_path" || true
			fi

			((success_count++))
			cd "$old_pwd" 2>/dev/null || true
			echo
		done

		local branches
		for repo_path in ${(k)remote_branches_by_repo}; do
			branches=(${=remote_branches_by_repo[$repo_path]})
			if [[ ${#branches[@]} -gt 0 ]]; then
				print_color yellow "Deleting ${#branches[@]} remote branches from $(basename "$repo_path")..."
				cd "$repo_path" 2>/dev/null || continue
				if git push origin --delete "${branches[@]}" 2>/dev/null; then
					print_color green "Successfully deleted remote branches: ${branches[*]}"
				else
					print_color red "Failed to batch-delete remote branches, trying individually..."
					for branch in "${branches[@]}"; do
						git push origin --delete "$branch" 2>/dev/null && \
							print_color green "Deleted remote: $branch" || \
							print_color red "Failed to delete remote: $branch"
					done
				fi
			fi
		done

		if [[ $success_count -eq $total_count ]]; then
			print_color green "Successfully deleted all $total_count worktrees."
		else
			print_color yellow "Deleted $success_count out of $total_count worktrees."
		fi

		return 0
	else
		delete_single_worktree "$worktree_path"
	fi
}
