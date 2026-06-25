#!/bin/zsh

# Emit one tab-separated row per git worktree found directly under the given
# created / checkout container dirs:
#
#   category<TAB>name<TAB>repo<TAB>branch<TAB>dirty<TAB>ahead<TAB>behind<TAB>path
#
# category is "created" for worktrees in the first dir, "checkout" for the
# second. Rows are sorted by path within each container. Subdirectories that are
# not git worktrees (no ".git" file containing a gitdir pointer) and missing
# container dirs are skipped silently. Status fields are derived read-only (no
# fetch): branch is "-" when detached or unresolvable; dirty is 1 when the
# working tree has any tracked or untracked change; ahead/behind are commit
# counts versus the upstream (0 when there is no upstream).
_worktree_list_entries() {
	local created_dir="$1"
	local checkout_dir="$2"
	local spec category dir wt_path name repo branch dirty ahead behind lr
	local -a parts
	for spec in "created:$created_dir" "checkout:$checkout_dir"; do
		category="${spec%%:*}"
		dir="${spec#*:}"
		[[ -n "$dir" && -d "$dir" ]] || continue
		while IFS= read -r wt_path; do
			[[ -n "$wt_path" ]] || continue
			[[ -f "$wt_path/.git" ]] || continue
			grep -q "^gitdir:" "$wt_path/.git" 2>/dev/null || continue

			name="${wt_path:t}"
			repo=$(get_worktree_project_name "$wt_path")

			branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
			[[ -z "$branch" || "$branch" == "HEAD" ]] && branch="-"

			dirty=0
			[[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]] && dirty=1

			ahead=0
			behind=0
			lr=$(git -C "$wt_path" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
			if [[ -n "$lr" ]]; then
				parts=(${=lr})
				behind="${parts[1]:-0}"
				ahead="${parts[2]:-0}"
			fi

			printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
				"$category" "$name" "$repo" "$branch" "$dirty" "$ahead" "$behind" "$wt_path"
		done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
	done
}

# Compose a human status from the raw dirty/ahead/behind fields and echo it as
# "<color> <text>" (color is a print_color name). Clean + in-sync is green;
# anything dirty is red; out-of-sync but clean is yellow.
_worktree_status_label() {
	local dirty="$1" ahead="$2" behind="$3"
	local text="" color="green"

	if [[ "$dirty" == "1" ]]; then
		color="red"
		text="dirty"
	fi
	if [[ "$ahead" != "0" || "$behind" != "0" ]]; then
		[[ "$dirty" == "1" ]] || color="yellow"
		[[ "$ahead" != "0" ]] && text="${text:+$text }↑$ahead"
		[[ "$behind" != "0" ]] && text="${text:+$text }↓$behind"
	fi
	[[ -n "$text" ]] || text="clean"

	echo "$color $text"
}

# `worktree list` — print every worktree under the created/checkout containers,
# grouped by container, with its parent repo, branch, and working-tree status.
# Columns are width-aligned to the widest value. Read-only: never fetches or
# mutates git state. Exits 0 even when there are no worktrees.
cmd_list() {
	local created_dir="${WCREATED_DIR:-$HOME/Programming/wcreated}"
	local checkout_dir="${WCHECKOUT_DIR:-$HOME/Programming/wcheckout}"

	local entries
	entries=$(_worktree_list_entries "$created_dir" "$checkout_dir")

	if [[ -z "$entries" ]]; then
		print_color yellow "No worktrees found in $created_dir or $checkout_dir"
		return 0
	fi

	local category name repo branch dirty ahead behind path

	# First pass: size the name/repo/branch columns to their widest value.
	local -i name_w=0 repo_w=0 branch_w=0
	while IFS=$'\t' read -r category name repo branch dirty ahead behind path; do
		[[ -n "$category" ]] || continue
		(( ${#name} > name_w )) && name_w=${#name}
		(( ${#repo} > repo_w )) && repo_w=${#repo}
		(( ${#branch} > branch_w )) && branch_w=${#branch}
	done <<< "$entries"

	print_color cyan "Worktrees"

	# Second pass: render grouped rows.
	local current_category="" label status_color status_text
	local -i created_count=0 checkout_count=0
	while IFS=$'\t' read -r category name repo branch dirty ahead behind path; do
		[[ -n "$category" ]] || continue

		if [[ "$category" != "$current_category" ]]; then
			current_category="$category"
			print -r --
			if [[ "$category" == "created" ]]; then
				print_color blue "created ($created_dir)"
			else
				print_color blue "checkout ($checkout_dir)"
			fi
		fi

		if [[ "$category" == "created" ]]; then
			((created_count++))
		else
			((checkout_count++))
		fi

		label=$(_worktree_status_label "$dirty" "$ahead" "$behind")
		status_color="${label%% *}"
		status_text="${label#* }"

		printf "  %-${name_w}s  %-${repo_w}s  %-${branch_w}s  " "$name" "$repo" "$branch"
		print_color "$status_color" "$status_text"
	done <<< "$entries"

	print -r --
	print_color green "$((created_count + checkout_count)) worktrees ($created_count created, $checkout_count checkout)"
}
