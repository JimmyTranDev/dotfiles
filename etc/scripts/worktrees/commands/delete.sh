#!/bin/zsh

select_fzf_multi() {
	local prompt="$1"
	shift
	[[ $# -gt 0 ]] && printf "%s\n" "$@" | fzf --multi --prompt="$prompt" || fzf --multi --prompt="$prompt"
}

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

	local gitdir_line
	gitdir_line=$(head -n1 "$worktree_path/.git")

	local worktree_gitdir
	if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
		worktree_gitdir="${match[1]}"
	else
		print_color red "Error: Could not parse .git file in $worktree_path"
		return 1
	fi

	local main_repo
	main_repo=$(dirname "$(dirname "$worktree_gitdir")")
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
		local worktree_list_output
		worktree_list_output=$(git worktree list --porcelain 2>/dev/null)

		local found_worktree=false
		while IFS= read -r line; do
			if [[ "$line" == "worktree $worktree_path" ]]; then
				found_worktree=true
			elif [[ "$found_worktree" == true && "$line" =~ ^branch ]]; then
				branch_name=$(echo "$line" | sed 's/^branch refs\/heads\///')
				print_color green "Found branch from worktree list: $branch_name"
				break
			elif [[ "$found_worktree" == true && "$line" =~ ^worktree ]]; then
				break
			fi
		done <<<"$worktree_list_output"
	fi

	if [[ -z "$branch_name" ]]; then
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

get_worktree_project_name_zsh() {
	local worktree_path="${1%/}"
	local git_file="$worktree_path/.git"
	if [[ -f "$git_file" ]]; then
		local gitdir
		gitdir=$(sed -n 's/^gitdir: *//p' "$git_file" 2>/dev/null)
		if [[ -n "$gitdir" ]]; then
			local repo_root
			repo_root=$(dirname "$(dirname "$(dirname "$gitdir")")")
			basename "$repo_root"
			return 0
		fi
	fi
	echo "unknown"
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
		typeset -A label_to_path
		for wt in "${available_worktrees[@]}"; do
			local wt_name="${wt##*/}"
			local project_name
			project_name=$(get_worktree_project_name_zsh "$wt")
			local label="[$project_name] $wt_name"
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
		local tmpdir
		tmpdir=$(mktemp -d)

		local pids=()
		for i in {1..$total_count}; do
			local wt_path="${worktrees_to_delete[$i]}"
			(
				if delete_single_worktree "$wt_path"; then
					echo 0 >"$tmpdir/result_$i"
				else
					echo 1 >"$tmpdir/result_$i"
				fi
			) >"$tmpdir/output_$i" 2>&1 &
			pids+=($!)
		done

		for pid in "${pids[@]}"; do
			wait "$pid" 2>/dev/null
		done

		local success_count=0
		for i in {1..$total_count}; do
			local wt_path="${worktrees_to_delete[$i]}"
			print_color cyan "Worktree $i/$total_count: $(basename "$wt_path")"
			cat "$tmpdir/output_$i"
			if [[ -f "$tmpdir/result_$i" && "$(cat "$tmpdir/result_$i")" == "0" ]]; then
				((success_count++))
			else
				print_color red "Failed to delete worktree: $wt_path"
			fi
			echo
		done

		rm -rf "$tmpdir"

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
