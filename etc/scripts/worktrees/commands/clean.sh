#!/bin/zsh

source "${0:A:h}/delete.sh"

cmd_clean_worktrees() {
	if ! check_tool git; then
		return 1
	fi

	local all_worktree_dirs=()
	for dir in "$WCREATED_DIR" "$WCHECKOUT_DIR"; do
		[[ -d "$dir" ]] && all_worktree_dirs+=("$dir")
	done

	if [[ ${#all_worktree_dirs[@]} -eq 0 ]]; then
		print_color red "No worktree directories found"
		return 1
	fi

	local available_worktrees=()
	for dir in "${all_worktree_dirs[@]}"; do
		while IFS= read -r wt; do
			[[ -n "$wt" ]] && available_worktrees+=("$wt")
		done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
	done

	if [[ ${#available_worktrees[@]} -eq 0 ]]; then
		print_color green "No worktrees found"
		return 0
	fi

	print_color yellow "Found ${#available_worktrees[@]} worktrees to check..."

	local worktrees_to_delete=()

	for wt_path in "${available_worktrees[@]}"; do
		if [[ ! -f "$wt_path/.git" ]]; then
			print_color yellow "  Skipping corrupted worktree: $wt_path"
			continue
		fi

		local gitdir_line
		gitdir_line=$(head -n1 "$wt_path/.git" 2>/dev/null)

		local worktree_gitdir
		if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
			worktree_gitdir="${match[1]}"
		else
			print_color yellow "  Could not parse .git file: $wt_path"
			continue
		fi

		local repo_root
		repo_root=$(dirname "$(dirname "$worktree_gitdir")")

		if [[ ! -d "$repo_root" ]]; then
			print_color yellow "  Could not find repo root for: $wt_path"
			continue
		fi

		local main_branch
		main_branch=$(find_main_branch "$repo_root") || {
			print_color yellow "  Could not find main branch for: $wt_path"
			continue
		}

		local develop_branch=""
		if git -C "$repo_root" show-ref --verify --quiet refs/heads/develop 2>/dev/null; then
			develop_branch="develop"
		fi

		local branch_name=""
		local old_pwd="$PWD"
		cd "$wt_path" 2>/dev/null && {
			branch_name=$(git branch --show-current 2>/dev/null)
			cd "$old_pwd"
		}

		if [[ -z "$branch_name" ]]; then
			print_color yellow "  Could not detect branch for: $wt_path"
			continue
		fi

		local is_merged=false
		local merged_into=""

		if git -C "$repo_root" merge-base --is-ancestor "$branch_name" "$main_branch" 2>/dev/null; then
			is_merged=true
			merged_into="$main_branch"
		elif [[ -n "$develop_branch" ]] && git -C "$repo_root" merge-base --is-ancestor "$branch_name" "$develop_branch" 2>/dev/null; then
			is_merged=true
			merged_into="$develop_branch"
		fi

		if [[ "$is_merged" == "true" ]]; then
			print_color yellow "  Branch '$branch_name' is merged into $merged_into - will delete"
			worktrees_to_delete+=("$wt_path")
		else
			print_color yellow "  Branch '$branch_name' is NOT merged - skipping"
		fi
	done

	if [[ ${#worktrees_to_delete[@]} -eq 0 ]]; then
		print_color green "No merged worktrees found to clean up."
		return 0
	fi

	print_color cyan "Will delete ${#worktrees_to_delete[@]} merged worktrees:"
	for wt in "${worktrees_to_delete[@]}"; do
		print_color cyan "  - $(basename "$wt")"
	done

	print_color yellow "Are you sure you want to delete these merged worktrees? (y/N)"
	local confirm
	read -r confirm
	if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
		print_color yellow "Cleanup cancelled."
		return 0
	fi

	local success_count=0
	local total_count=${#worktrees_to_delete[@]}

	for wt_path in "${worktrees_to_delete[@]}"; do
		print_color cyan "Deleting worktree $(($success_count + 1))/$total_count: $(basename "$wt_path")"
		if delete_single_worktree "$wt_path"; then
			((success_count++))
		else
			print_color red "Failed to delete worktree: $wt_path"
		fi
		echo
	done

	print_color green "===================="
	print_color green "Cleanup Complete"
	print_color green "===================="
	print_color green "Deleted $success_count out of $total_count merged worktrees."
}
