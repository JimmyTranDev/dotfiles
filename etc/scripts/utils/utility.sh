#!/bin/bash

_UTILITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
source "$_UTILITY_DIR/../consts/dirs.sh"

require_tool() {
    local missing=0
    for tool in "$@"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "Error: required tool '$tool' not found" >&2
            missing=1
        fi
    done
    return $missing
}

get_org_dirs() {
	local programming_dir="${1:-$HOME/Programming}"
	for dir in "$programming_dir"/*/; do
		[[ ! -d "$dir" ]] && continue
		local name="${dir%/}"
		name="${name##*/}"
		local excluded=false
		for excl in "${PROGRAMMING_EXCLUDED_DIRS[@]}"; do
			[[ "$name" == "$excl" ]] && excluded=true && break
		done
		$excluded || echo "$dir"
	done
}

slugify() {
	local input="$1"
	echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

# Print items with last_value first (if present), then the rest in original order.
# One item per line.
reorder_last_first() {
	local last_value="$1"
	shift
	local item
	if [[ -n "$last_value" ]]; then
		for item in "$@"; do
			[[ "$item" == "$last_value" ]] && printf '%s\n' "$item"
		done
		for item in "$@"; do
			[[ "$item" != "$last_value" ]] && printf '%s\n' "$item"
		done
	else
		for item in "$@"; do
			printf '%s\n' "$item"
		done
	fi
}

_fzf_select_items_and_cd() {
	local prompt="$1"
	local base_dir="$2"
	local last_file="$3"
	shift 3
	local items=()
	while IFS= read -r line; do
		[[ -n "$line" ]] && items+=("$line")
	done

	if [[ ${#items[@]} -eq 0 ]]; then
		echo "No items found in $base_dir"
		return 1
	fi

	local last_sel=""
	[[ -f "$last_file" ]] && last_sel=$(<"$last_file")

	local selected
	selected=$(reorder_last_first "$last_sel" "${items[@]}" | fzf --prompt="$prompt")
	if [[ -n "$selected" ]]; then
		echo "$selected" >"$last_file"
		local normalized_base_dir="${base_dir%/}"
		cd "$normalized_base_dir/$selected"
	else
		echo "No selection."
		return 1
	fi
}

# Emit repo paths (dirs containing a .git directory) relative to base_dir.
_emit_git_repo_paths() {
	local base_dir="$1"
	local max_depth="$2"
	local base_dir_with_slash="$3"
	find "$base_dir" -maxdepth "$max_depth" -name ".git" -type d 2>/dev/null | while IFS= read -r git_dir; do
		# ${git_dir%/.git} strips the trailing "/.git" without forking dirname.
		repo_path="${git_dir%/.git}"
		echo "${repo_path#$base_dir_with_slash}"
	done
}

# Emit worktree paths (dirs whose .git file points to a gitdir) relative to base_dir.
_emit_git_worktree_paths() {
	local base_dir="$1"
	local max_depth="$2"
	local base_dir_with_slash="$3"
	local gitdir_line
	find "$base_dir" -maxdepth "$max_depth" -name ".git" -type f 2>/dev/null | while IFS= read -r git_file; do
		# Read the first line in-shell instead of forking grep per worktree.
		gitdir_line=""
		IFS= read -r gitdir_line <"$git_file" 2>/dev/null
		if [[ "$gitdir_line" == gitdir:* ]]; then
			worktree_path="${git_file%/.git}"
			echo "${worktree_path#$base_dir_with_slash}"
		fi
	done
}

find_git_repos() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	_emit_git_repo_paths "$base_dir" "$max_depth" "$base_dir_with_slash" | sort
}

find_git_worktrees() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	_emit_git_worktree_paths "$base_dir" "$max_depth" "$base_dir_with_slash" | sort
}

find_git_worktrees_categorized() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	_emit_git_worktree_paths "$base_dir" "$max_depth" "$base_dir_with_slash" | while IFS= read -r relative_path; do
		if [[ "$relative_path" == /* ]]; then
			worktree_path="$relative_path"
		else
			worktree_path="${base_dir_with_slash}${relative_path}"
		fi
		if git -C "$worktree_path" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
			echo "[checkout] $relative_path"
		else
			echo "[created]  $relative_path"
		fi
	done | sort
}

get_worktree_project_name() {
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

# Emit both repo paths (.git dir) and worktree paths (.git file pointing to a
# gitdir) relative to base_dir in a SINGLE find traversal — half the directory
# walking of running the repo and worktree emitters back to back.
_emit_git_repo_and_worktree_paths() {
	local base_dir="$1"
	local max_depth="$2"
	local base_dir_with_slash="$3"
	local gitdir_line entry_path
	find "$base_dir" -maxdepth "$max_depth" -name ".git" 2>/dev/null | while IFS= read -r git_path; do
		entry_path="${git_path%/.git}"
		if [[ -d "$git_path" ]]; then
			echo "${entry_path#$base_dir_with_slash}"
		elif [[ -f "$git_path" ]]; then
			gitdir_line=""
			IFS= read -r gitdir_line <"$git_path" 2>/dev/null
			[[ "$gitdir_line" == gitdir:* ]] && echo "${entry_path#$base_dir_with_slash}"
		fi
	done
}

find_git_repos_and_worktrees() {
	local base_dir="$1"
	local max_depth="${2:-2}"
	base_dir="${base_dir%/}"
	local base_dir_with_slash="${base_dir}/"

	_emit_git_repo_and_worktree_paths "$base_dir" "$max_depth" "$base_dir_with_slash" | sort -u
}

# Print the mtime (epoch seconds) of a path on stdout, portably across GNU
# coreutils (stat -c %Y, Linux) and BSD stat (stat -f %m, macOS). The working
# flavor is probed once against "/" and cached in _STAT_MTIME_FMT, so each
# call forks a single stat instead of always trying the GNU form and falling
# back on BSD every time. Empty output and non-zero on a missing path; never
# fatal.
_stat_mtime() {
	if [[ -z "${_STAT_MTIME_FMT:-}" ]]; then
		if command stat -c %Y / >/dev/null 2>&1; then
			_STAT_MTIME_FMT="gnu"
		else
			_STAT_MTIME_FMT="bsd"
		fi
	fi
	if [[ "$_STAT_MTIME_FMT" == "gnu" ]]; then
		command stat -c %Y "$1" 2>/dev/null
	else
		command stat -f %m "$1" 2>/dev/null
	fi
}

# Recency timestamp for a project/worktree dir: prefer its .git (which git
# touches on use), fall back to the directory mtime, and report 0 when nothing
# exists so callers can still sort it last.
_recency_mtime() {
	local dir="${1%/}"
	if [[ -e "$dir/.git" ]]; then
		_stat_mtime "$dir/.git"
	elif [[ -e "$dir" ]]; then
		_stat_mtime "$dir"
	else
		printf '%s\n' 0
	fi
}

# Mark a project/worktree as most-recently-used by touching its .git (or the
# directory itself when there is none) so it floats to the top next time.
bump_project_recency() {
	local dir="${1%/}"
	if [[ -e "$dir/.git" ]]; then
		touch "$dir/.git" 2>/dev/null
	elif [[ -e "$dir" ]]; then
		touch "$dir" 2>/dev/null
	fi
}

# Collect every project (immediate child of each org dir under <programming>)
# and every git worktree in the <created>/<checkout> containers, one per line
# as: <mtime>\t<label>\t<absolute-path>. Labels mirror the picker UI
# ("[org] project", "[wcreated] name"). Missing container dirs are skipped
# silently. Output is unordered; callers sort by the leading mtime field.
_collect_project_dir_entries() {
	local programming_dir="${1:-$HOME/Programming}"
	local created_dir="${2:-$programming_dir/wcreated}"
	local checkout_dir="${3:-$programming_dir/wcheckout}"
	local org_dir org_name proj proj_name mtime
	local container label wt_name wt_path

	# Resolve the stat flavor once in THIS shell so the per-entry
	# "$(_recency_mtime ...)" command-substitution subshells below inherit the
	# cached _STAT_MTIME_FMT instead of re-detecting it (an extra stat fork) on
	# every entry.
	_stat_mtime / >/dev/null 2>&1

	while IFS= read -r org_dir; do
		[[ -d "$org_dir" ]] || continue
		org_name="${org_dir%/}"
		org_name="${org_name##*/}"
		while IFS= read -r proj; do
			[[ -n "$proj" ]] || continue
			proj_name="${proj##*/}"
			mtime="$(_recency_mtime "$proj")"
			printf '%s\t[%s] %s\t%s\n' "$mtime" "$org_name" "$proj_name" "$proj"
		done < <(find -L "${org_dir%/}" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null)
	done < <(get_org_dirs "$programming_dir")

	for container in "$created_dir" "$checkout_dir"; do
		[[ -d "$container" ]] || continue
		label="${container%/}"
		label="${label##*/}"
		while IFS= read -r wt_name; do
			[[ -n "$wt_name" ]] || continue
			wt_path="${container%/}/$wt_name"
			mtime="$(_recency_mtime "$wt_path")"
			printf '%s\t[%s] %s\t%s\n' "$mtime" "$label" "$wt_name" "$wt_path"
		done < <(find_git_repos_and_worktrees "$container")
	done
}

# fzf-pick a single project or worktree under ~/Programming and print its
# absolute path on stdout, listing the most-recently-used first (by .git/dir
# mtime; see _recency_mtime). The chosen entry is bumped to the top for next
# time and its "[org] project" label is mirrored into ~/.last_project so the
# ^o / ^n / worktree pickers stay in sync. Non-zero if nothing is chosen.
# Requires fzf and (via log_error) logging.sh to be sourced by the caller.
select_project_dir() {
	local programming_dir="$HOME/Programming"
	local created_dir="${WCREATED_DIR:-$programming_dir/wcreated}"
	local checkout_dir="${WCHECKOUT_DIR:-$programming_dir/wcheckout}"
	local last_file="$HOME/.last_project"

	local listing
	listing="$(_collect_project_dir_entries "$programming_dir" "$created_dir" "$checkout_dir" | sort -t$'\t' -k1,1 -rn | cut -f2-)"
	if [[ -z "$listing" ]]; then
		log_error "No projects or worktrees found in $programming_dir"
		return 1
	fi

	local selected
	selected=$(printf '%s\n' "$listing" | fzf --delimiter=$'\t' --with-nth=1 --prompt="Select project: ") || return 1
	[[ -z "$selected" ]] && return 1

	local label="${selected%%$'\t'*}"
	local project_path="${selected#*$'\t'}"
	printf '%s' "$label" >"$last_file"
	bump_project_recency "$project_path"
	printf '%s' "$project_path"
}

# Resolve the most-recently-selected project — the "[label]" that
# select_project_dir mirrors into ~/.last_project — back to an absolute path,
# with no fzf prompt. Reuses _collect_project_dir_entries so the stored label
# always matches, then bumps the resolved project's recency for picker parity.
# Prints the absolute path on stdout. Returns non-zero *silently* (no last
# project recorded, a blank label, or a label that no longer resolves to an
# existing directory) so the caller can fall back to the fzf picker. The four
# args default to the production paths and are overridable for tests.
last_project_dir() {
	local programming_dir="${1:-$HOME/Programming}"
	local created_dir="${2:-${WCREATED_DIR:-$programming_dir/wcreated}}"
	local checkout_dir="${3:-${WCHECKOUT_DIR:-$programming_dir/wcheckout}}"
	local last_file="${4:-$HOME/.last_project}"

	[[ -s "$last_file" ]] || return 1
	local last_label
	last_label="$(<"$last_file")"
	[[ -n "$last_label" ]] || return 1

	# Find the entry whose label (2nd tab field) matches the stored label and
	# capture its absolute path (3rd field). `entry_path` is named to avoid
	# zsh's special `path` array (tied to $PATH); `_` discards the mtime field.
	local entry_label entry_path found=""
	while IFS=$'\t' read -r _ entry_label entry_path; do
		if [[ "$entry_label" == "$last_label" ]]; then
			found="$entry_path"
			break
		fi
	done < <(_collect_project_dir_entries "$programming_dir" "$created_dir" "$checkout_dir")

	[[ -n "$found" && -d "$found" ]] || return 1

	bump_project_recency "$found"
	printf '%s' "$found"
}

# The set of programs the stacked-pane launcher can open. "empty" means a plain
# shell pane with no command. Keep this list in sync with select_pane_tool's UI.
PANE_TOOLS=(nvim opencode storecode empty)

# fzf-pick which program to open in a new stacked pane — one of nvim, opencode,
# storecode, or empty (a plain shell). The previously-chosen tool (mirrored into
# ~/.last_pane_tool) floats to the top so repeat use is a single Enter. Prints
# the choice on stdout; non-zero if cancelled. Requires fzf.
select_pane_tool() {
	local last_file="${1:-$HOME/.last_pane_tool}"
	local last_sel=""
	[[ -s "$last_file" ]] && last_sel="$(<"$last_file")"

	local selected
	selected="$(reorder_last_first "$last_sel" "${PANE_TOOLS[@]}" | fzf --prompt="Open: ")" || return 1
	[[ -z "$selected" ]] && return 1
	printf '%s' "$selected"
}

# Resolve the most-recently-chosen pane tool (mirrored into ~/.last_pane_tool by
# select_pane_tool). Prints it on stdout; non-zero *silently* when none is
# recorded so the caller can fall back to a default.
last_pane_tool() {
	local last_file="${1:-$HOME/.last_pane_tool}"
	[[ -s "$last_file" ]] || return 1
	local tool
	tool="$(<"$last_file")"
	[[ -n "$tool" ]] || return 1
	printf '%s' "$tool"
}

# Parse a `zellij action dump-layout` KDL (read from stdin) and print the
# absolute cwd of the single globally-focused leaf pane. The dump emits a
# layout-level base `cwd "<abs>"` (space form) plus per-pane `cwd="<rel-or-abs>"`
# (attribute form); exactly one leaf `pane ... focus=true ...` is the focused
# pane. A pane cwd is resolved relative to the base unless it is already
# absolute. Prints nothing and returns non-zero when no focused pane carries a
# cwd. Pure text munging — no zellij call — so it is unit-testable.
_focused_pane_dir_from_layout() {
	local layout base_cwd pane_line pane_cwd
	layout="$(cat)"

	# Base cwd: the layout-level `cwd "<abs>"` (space form). Pane lines use the
	# `cwd="..."` attribute form (with '='), so this regex never matches them.
	base_cwd="$(printf '%s\n' "$layout" | sed -n 's/^[[:space:]]*cwd "\([^"]*\)".*/\1/p' | head -n1)"

	# Focused pane: the one `pane ... focus=true ...` line that carries a cwd
	# attribute (the focused tab line also has focus=true but starts with "tab").
	pane_line="$(printf '%s\n' "$layout" | grep 'focus=true' | grep -E '^[[:space:]]*pane[[:space:]]' | grep 'cwd="' | head -n1)"
	[[ -n "$pane_line" ]] || return 1
	pane_cwd="$(printf '%s\n' "$pane_line" | sed -n 's/.*[[:space:]]cwd="\([^"]*\)".*/\1/p')"
	[[ -n "$pane_cwd" ]] || return 1

	if [[ "$pane_cwd" == /* ]]; then
		printf '%s' "$pane_cwd"
	elif [[ -n "$base_cwd" ]]; then
		printf '%s' "${base_cwd%/}/$pane_cwd"
	else
		printf '%s' "$pane_cwd"
	fi
}

# Print the absolute cwd of the currently-focused zellij pane (see
# _focused_pane_dir_from_layout). Returns non-zero *silently* when not inside a
# zellij session, when dump-layout fails, or when the resolved path is not an
# existing directory — so callers can fall back to a picker.
current_pane_dir() {
	[[ -n "${ZELLIJ:-}" ]] || return 1
	local dir
	dir="$(zellij action dump-layout 2>/dev/null | _focused_pane_dir_from_layout)" || return 1
	[[ -n "$dir" && -d "$dir" ]] || return 1
	printf '%s' "$dir"
}

# Print the absolute cwd of the pane to the RIGHT of the focused one: move focus
# right, read that pane's dir (see current_pane_dir), then move focus back left
# so the caller opens its new pane back at the original position. This is the
# "go right, grab the project, come back left" flow the keybind wants, and it
# stays correct even when the left and right panes share a project dir (no
# brittle before/after comparison). The settle sleeps let each focus change land
# before dump-layout reads it (and before the caller spawns a pane). With no
# pane to the right the move-focus right is a no-op. Returns non-zero *silently*
# when not in zellij or the dir can't be resolved, so callers fall back to a
# picker.
right_pane_dir() {
	[[ -n "${ZELLIJ:-}" ]] || return 1

	zellij action move-focus right 2>/dev/null
	sleep 0.15

	local dir
	dir="$(current_pane_dir)" || dir=""

	zellij action move-focus left 2>/dev/null
	sleep 0.1

	[[ -n "$dir" ]] || return 1
	printf '%s' "$dir"
}

# Open a new stacked zellij pane rooted at $1 running tool $2 (one of
# PANE_TOOLS). "empty" opens a plain shell pane; every other tool runs in a pane
# that closes itself on exit (--close-on-exit). The focused tab is renamed after
# the project folder; callers should reindex tab names afterward.
open_tool_pane() {
	local target_dir="$1"
	local tool="$2"

	if [[ "$tool" == "empty" ]]; then
		zellij action new-pane --cwd "$target_dir" --stacked
	else
		zellij action new-pane --cwd "$target_dir" --stacked --close-on-exit -- "$tool"
	fi

	zellij action rename-tab "$(basename "$target_dir")"
}
