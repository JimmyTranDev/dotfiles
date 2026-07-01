#!/bin/zsh

source "${0:A:h}/delete.sh"

cmd_clean_worktrees() {
	if ! check_tool git; then
		return 1
	fi

	local dry_run=false assume_yes=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=true
			shift
			;;
		-y | --yes)
			assume_yes=true
			shift
			;;
		-h | --help)
			print_color cyan "Usage: worktree clean [--dry-run] [-y|--yes]"
			print_color cyan "  Delete every managed worktree whose branch is already merged"
			print_color cyan "  into its base branch (main/master) or develop, then delete the"
			print_color cyan "  worktree and its local branch. Created worktrees also delete"
			print_color cyan "  their remote branch; checkout worktrees keep it."
			print_color cyan "  --dry-run shows the plan without deleting; -y skips the prompt."
			return 0
			;;
		*)
			print_color yellow "Unknown option: $1"
			shift
			;;
		esac
	done

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
	local -A fetched_repos=()

	local gitdir_line worktree_gitdir repo_root main_branch develop_branch branch_name old_pwd is_merged merged_into
	for wt_path in "${available_worktrees[@]}"; do
		if [[ ! -f "$wt_path/.git" ]]; then
			print_color yellow "  Skipping corrupted worktree: $wt_path"
			continue
		fi

		gitdir_line=$(head -n1 "$wt_path/.git" 2>/dev/null)

		if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
			worktree_gitdir="${match[1]}"
		else
			print_color yellow "  Could not parse .git file: $wt_path"
			continue
		fi

		repo_root=$(dirname "$(dirname "$worktree_gitdir")")

		if [[ ! -d "$repo_root" ]]; then
			print_color yellow "  Could not find repo root for: $wt_path"
			continue
		fi

		main_branch=$(find_base_branch "$repo_root") || {
			print_color yellow "  Could not find main branch for: $wt_path"
			continue
		}

		develop_branch=""
		if git -C "$repo_root" show-ref --verify --quiet refs/heads/develop 2>/dev/null ||
			git -C "$repo_root" show-ref --verify --quiet refs/remotes/origin/develop 2>/dev/null; then
			develop_branch="develop"
		fi

		branch_name=""
		old_pwd="$PWD"
		cd "$wt_path" 2>/dev/null && {
			branch_name=$(git branch --show-current 2>/dev/null)
			cd "$old_pwd"
		}

		if [[ -z "$branch_name" ]]; then
			print_color yellow "  Could not detect branch for: $wt_path"
			continue
		fi

		is_merged=false
		merged_into=""

		if [[ -z "${fetched_repos[$repo_root]:-}" ]]; then
			git -C "$repo_root" fetch --quiet 2>/dev/null
			fetched_repos[$repo_root]=1
		fi

		if git -C "$repo_root" merge-base --is-ancestor "$branch_name" "origin/$main_branch" 2>/dev/null; then
			is_merged=true
			merged_into="origin/$main_branch"
		elif [[ -n "$develop_branch" ]] && git -C "$repo_root" merge-base --is-ancestor "$branch_name" "origin/$develop_branch" 2>/dev/null; then
			is_merged=true
			merged_into="origin/$develop_branch"
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

	if [[ "$dry_run" == true ]]; then
		print_color yellow "Dry run — no changes made."
		return 0
	fi

	if [[ "$assume_yes" != true ]]; then
		print_color yellow "Are you sure you want to delete these merged worktrees? (y/N)"
		local confirm
		read -r confirm
		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			print_color yellow "Cleanup cancelled."
			return 0
		fi
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
