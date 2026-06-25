#!/bin/zsh

# worktree merge — integrate every managed worktree's branch into its local base
# branch (develop/main/master) with NO push, then delete the merged worktree and
# its local branch. Worktrees whose branch is already merged are simply deleted
# ("clear already merged worktrees"). On a merge conflict the merge is left in
# progress so it can be resolved, and the run stops so you can fix it and re-run.

# Remove a worktree and its now-merged local branch. Local only: never pushes and
# never deletes a remote branch, honoring the no-push contract.
merge_remove_worktree_local() {
	local wt_path="$1" main_repo="$2" branch="$3"

	if git -C "$main_repo" worktree remove "$wt_path" 2>/dev/null; then
		print_color green "  Removed worktree: $(basename "$wt_path")"
	else
		git -C "$main_repo" worktree remove --force "$wt_path" 2>/dev/null || true
	fi

	if [[ -n "$branch" ]] && git -C "$main_repo" show-ref --verify --quiet "refs/heads/$branch"; then
		if git -C "$main_repo" branch -d "$branch" 2>/dev/null; then
			print_color green "  Deleted local branch: $branch"
		else
			git -C "$main_repo" branch -D "$branch" 2>/dev/null &&
				print_color yellow "  Force-deleted local branch: $branch"
		fi
	fi

	[[ -d "$wt_path" ]] && rm -rf "$wt_path" 2>/dev/null
	return 0
}

# Returns 0 when the repo's working tree is clean and not mid-merge.
merge_is_clean_repo() {
	local repo="$1"
	git -C "$repo" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 && return 1
	[[ -z "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]
}

cmd_merge_worktrees() {
	check_tool git || return 1

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
			print_color cyan "Usage: worktree merge [--dry-run] [-y|--yes]"
			print_color cyan "  Merge each worktree's branch into its local base branch"
			print_color cyan "  (develop/main/master) with NO push, then delete the worktree"
			print_color cyan "  and its local branch. Already-merged worktrees are deleted."
			print_color cyan "  On conflict the merge is left in progress; resolve it, commit,"
			print_color cyan "  then re-run 'worktree merge' to continue."
			return 0
			;;
		*)
			print_color yellow "Unknown option: $1"
			shift
			;;
		esac
	done

	local all_worktree_dirs=()
	local dir
	for dir in "$WCREATED_DIR" "$WCHECKOUT_DIR"; do
		[[ -d "$dir" ]] && all_worktree_dirs+=("$dir")
	done
	if [[ ${#all_worktree_dirs[@]} -eq 0 ]]; then
		print_color red "No worktree directories found"
		return 1
	fi

	local available_worktrees=()
	local wt
	for dir in "${all_worktree_dirs[@]}"; do
		while IFS= read -r wt; do
			[[ -n "$wt" ]] && available_worktrees+=("$wt")
		done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
	done
	if [[ ${#available_worktrees[@]} -eq 0 ]]; then
		print_color green "No worktrees found"
		return 0
	fi

	print_color yellow "Scanning ${#available_worktrees[@]} worktrees..."

	# Parallel arrays: branches to merge then delete, and already-merged to delete.
	local merge_paths=() merge_repos=() merge_branches=() merge_bases=()
	local del_paths=() del_repos=() del_branches=()

	local wt_path main_repo branch_name base_branch
	for wt_path in "${available_worktrees[@]}"; do
		if [[ ! -f "$wt_path/.git" ]]; then
			print_color yellow "  Skip (corrupted): $(basename "$wt_path")"
			continue
		fi

		# Resolve the work-tree root (NOT the .git dir) so checkout/merge run in a
		# work tree. rev-parse --git-common-dir gives <repo>/.git; :h -> <repo>.
		main_repo=$(git -C "$wt_path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
		main_repo="${main_repo:h}"
		if [[ -z "$main_repo" || ! -d "$main_repo" ]]; then
			print_color yellow "  Skip (no main repo): $(basename "$wt_path")"
			continue
		fi

		branch_name=$(git -C "$wt_path" branch --show-current 2>/dev/null)
		if [[ -z "$branch_name" ]]; then
			print_color yellow "  Skip (detached HEAD): $(basename "$wt_path")"
			continue
		fi

		base_branch=$(find_base_branch "$main_repo") || {
			print_color yellow "  Skip (no base branch): $(basename "$wt_path")"
			continue
		}

		if [[ "$branch_name" == "$base_branch" ]]; then
			print_color yellow "  Skip (on base '$base_branch'): $(basename "$wt_path")"
			continue
		fi

		if [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]]; then
			print_color yellow "  Skip (uncommitted changes): $(basename "$wt_path") [$branch_name]"
			continue
		fi

		if git -C "$main_repo" merge-base --is-ancestor "$branch_name" "$base_branch" 2>/dev/null; then
			del_paths+=("$wt_path")
			del_repos+=("$main_repo")
			del_branches+=("$branch_name")
		else
			merge_paths+=("$wt_path")
			merge_repos+=("$main_repo")
			merge_branches+=("$branch_name")
			merge_bases+=("$base_branch")
		fi
	done

	if [[ ${#del_paths[@]} -eq 0 && ${#merge_paths[@]} -eq 0 ]]; then
		print_color green "Nothing to do — no mergeable or already-merged worktrees."
		return 0
	fi

	print_color cyan "=== Plan ==="
	local i
	if ((${#merge_paths[@]})); then
		print_color cyan "Merge (local, no push) then delete:"
		for ((i = 1; i <= ${#merge_paths[@]}; i++)); do
			print_color cyan "  - $(basename "${merge_paths[$i]}")  [${merge_branches[$i]} -> ${merge_bases[$i]}]"
		done
	fi
	if ((${#del_paths[@]})); then
		print_color cyan "Already merged — delete only:"
		for ((i = 1; i <= ${#del_paths[@]}; i++)); do
			print_color cyan "  - $(basename "${del_paths[$i]}")  [${del_branches[$i]}]"
		done
	fi

	if [[ "$dry_run" == true ]]; then
		print_color yellow "Dry run — no changes made."
		return 0
	fi

	if [[ "$assume_yes" != true ]]; then
		print_color yellow "Proceed with local merge (no push) and deletion? (y/N)"
		local confirm
		read -r confirm
		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			print_color yellow "Aborted."
			return 0
		fi
	fi

	local merged_count=0 deleted_count=0 skipped_count=0

	for ((i = 1; i <= ${#del_paths[@]}; i++)); do
		print_color cyan "Deleting already-merged: $(basename "${del_paths[$i]}") [${del_branches[$i]}]"
		merge_remove_worktree_local "${del_paths[$i]}" "${del_repos[$i]}" "${del_branches[$i]}"
		((deleted_count++))
	done

	local repo branch base f
	for ((i = 1; i <= ${#merge_paths[@]}; i++)); do
		wt_path="${merge_paths[$i]}"
		repo="${merge_repos[$i]}"
		branch="${merge_branches[$i]}"
		base="${merge_bases[$i]}"

		print_color cyan "Merging '$branch' -> '$base' in $(basename "$repo")..."

		if ! merge_is_clean_repo "$repo"; then
			print_color yellow "  Skip: main repo is dirty or mid-merge — resolve it first."
			((skipped_count++))
			continue
		fi

		if [[ "$(git -C "$repo" branch --show-current 2>/dev/null)" != "$base" ]]; then
			if ! git -C "$repo" checkout "$base" 2>/dev/null; then
				print_color yellow "  Skip: could not checkout '$base' (checked out elsewhere?)."
				((skipped_count++))
				continue
			fi
		fi

		if git -C "$repo" merge --no-ff --no-edit "$branch" >/dev/null 2>&1; then
			print_color green "  Merged cleanly into '$base'."
			merge_remove_worktree_local "$wt_path" "$repo" "$branch"
			((merged_count++))
		else
			print_color red "  CONFLICT merging '$branch' into '$base'."
			while IFS= read -r f; do
				[[ -n "$f" ]] && print_color red "    conflict: $f"
			done < <(git -C "$repo" diff --name-only --diff-filter=U 2>/dev/null)
			print_color yellow "  Merge left in progress in: $repo"
			print_color yellow "  Resolve the conflicts, then: git -C '$repo' commit --no-edit"
			print_color yellow "  Agents: load the 'merge-conflict-resolution' skill to finish it."
			print_color yellow "  Then re-run 'worktree merge' to continue the rest."
			print_color cyan "=== Partial summary ==="
			print_color green "  Merged & deleted:        $merged_count"
			print_color green "  Already-merged deleted:  $deleted_count"
			[[ $skipped_count -gt 0 ]] && print_color yellow "  Skipped:                 $skipped_count"
			return 2
		fi
	done

	print_color green "===================="
	print_color green "Merge Complete"
	print_color green "===================="
	print_color green "Merged & deleted:        $merged_count"
	print_color green "Already-merged deleted:  $deleted_count"
	[[ $skipped_count -gt 0 ]] && print_color yellow "Skipped:                 $skipped_count"
	return 0
}
