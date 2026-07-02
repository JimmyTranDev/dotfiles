#!/bin/zsh

WORKTREE_CORE_LIB_DIR="${0:A:h}"
source "$WORKTREE_CORE_LIB_DIR/utility.sh"
source "$WORKTREE_CORE_LIB_DIR/detect.sh"
source "$WORKTREE_CORE_LIB_DIR/git.sh"

check_tool() {
	local tool="${1:-}"
	if [[ -z "$tool" ]]; then
		print_color red "Error: No tool specified to check"
		return 1
	fi
	if ! command -v "$tool" &>/dev/null; then
		print_color red "Error: Required tool '$tool' not found."
		return 1
	fi
	return 0
}

print_color() {
	local color="${1:-white}"
	shift
	if [[ $# -gt 0 ]]; then
		print -P "%F{$color}$*%f"
	else
		print -P "%F{$color}%f"
	fi
}

select_fzf() {
	local prompt="$1"
	shift
	[[ $# -gt 0 ]] && printf "%s\n" "$@" | fzf --prompt="$prompt" || fzf --prompt="$prompt"
}

select_fzf_multi() {
	local prompt="$1"
	shift
	[[ $# -gt 0 ]] && printf "%s\n" "$@" | fzf --multi --prompt="$prompt" || fzf --multi --prompt="$prompt"
}

# Parse the gitdir path from a worktree's .git file.
# Echoes the gitdir on success; returns 1 if the .git file can't be parsed.
parse_worktree_gitdir() {
	local worktree_path="$1"
	local gitdir_line
	gitdir_line=$(head -n1 "$worktree_path/.git")
	if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
		echo "${match[1]}"
		return 0
	fi
	return 1
}

# Resolve a worktree's main repository path (two dirnames up from its gitdir).
# Echoes the main repo path on success; returns 1 if the .git file can't be parsed.
resolve_main_repo_from_worktree() {
	local worktree_path="$1"
	local worktree_gitdir
	worktree_gitdir=$(parse_worktree_gitdir "$worktree_path") || return 1
	dirname "$(dirname "$worktree_gitdir")"
}

# Find a branch name by scanning `git worktree list --porcelain` in a repo.
# $1 = main repo path; $2 = match target (full worktree path for exact mode,
# basename for basename mode); $3 = mode: "exact" (default) or "basename".
# Echoes the branch name if found, empty otherwise.
worktree_branch_from_porcelain() {
	local main_repo="$1"
	local match_target="$2"
	local mode="${3:-exact}"
	local worktree_list_output line branch="" found_worktree=false is_target
	worktree_list_output=$(git -C "$main_repo" worktree list --porcelain 2>/dev/null)
	while IFS= read -r line; do
		is_target=false
		if [[ "$mode" == "exact" && "$line" == "worktree $match_target" ]]; then
			is_target=true
		elif [[ "$mode" == "basename" && "$line" =~ worktree.*/$match_target$ ]]; then
			is_target=true
		fi

		if [[ "$is_target" == true ]]; then
			found_worktree=true
		elif [[ "$found_worktree" == true && "$line" =~ ^branch ]]; then
			branch=$(echo "$line" | sed 's/^branch refs\/heads\///')
			break
		elif [[ "$found_worktree" == true && "$line" =~ ^worktree ]]; then
			break
		fi
	done <<<"$worktree_list_output"
	echo "$branch"
}

# Advance a base branch ref to a new tip WITHOUT checking it out — the primitive
# that keeps worktree->base integration entirely off the main repo's working
# tree. git refuses `push .`/`branch -f` on a checked-out branch and a bare
# `update-ref` on a checked-out branch leaves the index inconsistent, so when
# <base> is the repo's checked-out branch we first DETACH HEAD at the current
# (old) commit — leaving the working tree untouched and clean — then move the ref
# with an atomic compare-and-swap. The <old_tip> guard makes the CAS race-safe:
# a concurrent advance fails the update instead of clobbering it.
#
#   advance_base_ref <repo> <base> <new_tip> <old_tip>
#
# Returns 0 on success (ref moved, repo left clean; detached at <old_tip> if it
# had <base> checked out), 1 on failure (non-fast-forward move refused, could not
# detach, or the CAS failed because the ref no longer pointed at <old_tip>). On
# failure the caller should re-rebase onto the (moved) base and retry.
advance_base_ref() {
	local repo="$1" base="$2" new_tip="$3" old_tip="$4"

	# Nothing to do when the ref is already at the target (idempotent re-runs).
	[[ "$new_tip" == "$old_tip" ]] && return 0

	# Refuse a non-fast-forward move: <old_tip> must be an ancestor of <new_tip>,
	# so the base only ever advances linearly (never rewinds or rewrites history).
	# The caller rebases the branch onto the base first, which guarantees this in
	# the normal path; a refusal means the local base diverged and needs a manual
	# look rather than a silent clobber.
	if ! git -C "$repo" merge-base --is-ancestor "$old_tip" "$new_tip" 2>/dev/null; then
		print_color red "  Refusing to advance '$base' — the move is not a fast-forward (base diverged)."
		return 1
	fi

	# Detach only when <base> is the checked-out branch; HEAD stays at <old_tip>
	# so the working tree/index are never touched.
	if [[ "$(git -C "$repo" branch --show-current 2>/dev/null)" == "$base" ]]; then
		if ! git -C "$repo" checkout --detach >/dev/null 2>&1; then
			print_color red "  Could not detach HEAD in $(basename "$repo") to advance '$base' off-checkout."
			return 1
		fi
	fi

	if ! git -C "$repo" update-ref "refs/heads/$base" "$new_tip" "$old_tip" 2>/dev/null; then
		print_color red "  Could not advance '$base' (it moved under us; re-rebase and retry)."
		return 1
	fi
	return 0
}

resolve_unique_dir() {
	local base_dir="$1"

	if [[ ! -d "$base_dir" ]]; then
		echo "$base_dir"
		return 0
	fi

	local suffix=1
	while [[ -d "${base_dir}-${suffix}" ]]; do
		((suffix++))
	done

	echo "${base_dir}-${suffix}"
}

# Decide a worktree branch name from a single raw input, honoring a JIRA key
# when one is supplied. Pure and deterministic: the caller fetches the JIRA
# summary (via acli) and passes it in, so this function does no I/O itself.
#   - input matches JIRA_PATTERN + non-empty summary -> "<KEY>-<slug(summary)>"
#   - input matches JIRA_PATTERN, empty/blank summary -> "<KEY>"
#   - anything else                                   -> sanitized branch name
# Echoes an empty string when the input sanitizes to nothing (caller aborts).
compute_branch_name() {
	local input="$1" summary="${2:-}"
	local clean_summary

	if [[ "$input" =~ $JIRA_PATTERN ]]; then
		if [[ -n "$summary" ]]; then
			clean_summary=$(slugify "$(echo "$summary" | head -1 | sed 's/\x1b\[[0-9;]*m//g')")
			if [[ -n "$clean_summary" ]]; then
				echo "${input}-${clean_summary}"
			else
				echo "$input"
			fi
		else
			echo "$input"
		fi
	else
		echo "$input" | head -1 | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\n\r' | sed 's/[^a-zA-Z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
	fi
}

get_folder_name_from_branch() {
	local branch_name="$1"

	if [[ -z "$branch_name" ]]; then
		print_color red "Error: Branch name is required"
		return 1
	fi

	if [[ "$branch_name" =~ ^[^/]+/(.+)$ ]]; then
		echo "${match[1]}"
	else
		echo "$branch_name"
	fi
}

setup_project() {
	local proj
	proj=$(select_project) || return 1

	if [[ -z "$proj" || ! -d "$PROGRAMMING_DIR/$proj" ]]; then
		print_color red "No valid project selected."
		return 1
	fi

	echo "$proj" >"$HOME/.last_project"
	echo "$PROGRAMMING_DIR/$proj"
}

select_project() {
	local last_proj_file="$HOME/.last_project"
	local last_proj=""
	[[ -f "$last_proj_file" ]] && last_proj=$(<"$last_proj_file")

	local all_projects=()
	local org_name dirname
	while IFS= read -r org_dir; do
		[[ ! -d "$org_dir" ]] && continue
		org_name="${org_dir%/}"
		org_name="${org_name##*/}"
		for dir in "$org_dir"/*/; do
			[[ -d "$dir" ]] || continue
			dirname="${dir%/}"
			dirname="${dirname##*/}"
			all_projects+=("$org_name/$dirname")
		done
	done < <(get_org_dirs "$PROGRAMMING_DIR")

	if [[ ${#all_projects[@]} -eq 0 ]]; then
		print_color red "No projects found in $PROGRAMMING_DIR"
		return 1
	fi

	local projects_list=()
	while IFS= read -r p; do
		projects_list+=("$p")
	done < <(reorder_last_first "$last_proj" "${all_projects[@]}")

	select_fzf "Select project folder: " "${projects_list[@]}"
}

install_dependencies() {
	local worktree_path="$1"

	if [[ -z "$worktree_path" || ! -d "$worktree_path" ]]; then
		print_color red "Error: Invalid worktree path"
		return 1
	fi

	cd "$worktree_path" || {
		print_color red "Error: Could not change to worktree directory"
		return 1
	}

	local pm
	pm=$(detect_node_package_manager)

	if [[ -n "$pm" ]]; then
		print_color cyan "Running $pm install..."
		if ! "$pm" install; then
			print_color yellow "Warning: $pm install failed"
			return 1
		fi
	else
		print_color yellow "No supported lockfile found. Skipping dependency installation."
	fi
}

get_repository() {
	local repo_name="$1"
	local programming_dir="${PROGRAMMING_DIR:-$HOME/Programming}"

	local search_dirs=()
	while IFS= read -r org_dir; do
		[[ -d "$org_dir" ]] && search_dirs+=("${org_dir%/}")
	done < <(get_org_dirs "$programming_dir")
	[[ ${#search_dirs[@]} -eq 0 && -d "$programming_dir" ]] && search_dirs+=("$programming_dir")

	if [[ ${#search_dirs[@]} -eq 0 ]]; then
		print_color red "Error: No programming directories found" >&2
		return 1
	fi

	local repos=()
	local repo_labels=()
	local category repo_path
	for dir in "${search_dirs[@]}"; do
		category=$(basename "$dir")
		while IFS= read -r -d '' git_dir; do
			repo_path="$(dirname "$git_dir")"
			repos+=("$repo_path")
			repo_labels+=("[$category] $(basename "$repo_path")")
		done < <(find "$dir" -maxdepth 2 -name ".git" -type d -print0 2>/dev/null)
	done

	# Also scan worktree directories (wcreated and wcheckout)
	local wcreated_dir="${WCREATED_DIR:-$programming_dir/wcreated}"
	local wcheckout_dir="${WCHECKOUT_DIR:-$programming_dir/wcheckout}"
	for wt_dir in "$wcreated_dir" "$wcheckout_dir"; do
		[[ ! -d "$wt_dir" ]] && continue
		local wt_label="$(basename "$wt_dir")"
		for wt_entry in "$wt_dir"/*/; do
			[[ ! -d "$wt_entry" ]] && continue
			if [[ -d "$wt_entry/.git" ]] || [[ -f "$wt_entry/.git" ]]; then
				local wt_path="${wt_entry%/}"
				repos+=("$wt_path")
				repo_labels+=("[$wt_label] $(basename "$wt_path")")
			fi
		done
	done

	if [[ ${#repos[@]} -eq 0 ]]; then
		print_color red "No git repositories found" >&2
		return 1
	fi

	if [[ -n "$repo_name" ]]; then
		for repo in "${repos[@]}"; do
			if [[ "$(basename "$repo")" == "$repo_name" ]]; then
				echo "$repo"
				return 0
			fi
		done
		print_color red "Error: Repository '$repo_name' not found" >&2
		return 1
	fi

	print_color cyan "Scanning for git repositories..." >&2
	if check_tool fzf; then
		local selected
		selected=$(printf '%s\n' "${repo_labels[@]}" | fzf --prompt="Select repository: " --height=40% --reverse)
		[[ -z "$selected" ]] && return 1

		# Match by both label and basename to handle duplicate names across categories
		for i in {1..${#repo_labels[@]}}; do
			if [[ "${repo_labels[$i]}" == "$selected" ]]; then
				echo "${repos[$i]}"
				return 0
			fi
		done
	fi

	return 1
}
