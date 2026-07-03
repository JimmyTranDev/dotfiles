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

# Emit every project (immediate child of each org dir under <programming>) and
# every git worktree in the <created>/<checkout> containers as "<label>\t<path>"
# — the label and path of a _collect_project_dir_entries row without its leading
# recency mtime. Split out so the fast (single python os.stat) and portable
# (per-entry _recency_mtime) mtime passes can share one directory walk. Missing
# container dirs are skipped silently.
_emit_project_dir_labels() {
	local programming_dir="$1"
	local created_dir="$2"
	local checkout_dir="$3"
	local org_dir org_name proj proj_name
	local container label wt_name wt_path

	while IFS= read -r org_dir; do
		[[ -d "$org_dir" ]] || continue
		org_name="${org_dir%/}"
		org_name="${org_name##*/}"
		while IFS= read -r proj; do
			[[ -n "$proj" ]] || continue
			proj_name="${proj##*/}"
			printf '[%s] %s\t%s\n' "$org_name" "$proj_name" "$proj"
		done < <(find -L "${org_dir%/}" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null)
	done < <(get_org_dirs "$programming_dir")

	for container in "$created_dir" "$checkout_dir"; do
		[[ -d "$container" ]] || continue
		label="${container%/}"
		label="${label##*/}"
		while IFS= read -r wt_name; do
			[[ -n "$wt_name" ]] || continue
			wt_path="${container%/}/$wt_name"
			printf '[%s] %s\t%s\n' "$label" "$wt_name" "$wt_path"
		done < <(find_git_repos_and_worktrees "$container")
	done
}

# Collect every project (immediate child of each org dir under <programming>)
# and every git worktree in the <created>/<checkout> containers, one per line
# as: <mtime>\t<label>\t<path>. Labels mirror the picker UI ("[org] project",
# "[wcreated] name"). Missing container dirs are skipped silently. Output is
# unordered; callers sort by the leading mtime field.
#
# The recency mtime (mtime of <dir>/.git when present, else <dir>, else 0 —
# mirroring _recency_mtime) is resolved for the whole listing in ONE python
# os.stat pass when python3 is available, replacing the previous per-entry
# command-substitution subshell + stat fork. Falls back to the portable
# per-entry _recency_mtime loop when python3 is absent.
_collect_project_dir_entries() {
	local programming_dir="${1:-$HOME/Programming}"
	local created_dir="${2:-$programming_dir/wcreated}"
	local checkout_dir="${3:-$programming_dir/wcheckout}"

	if command -v python3 >/dev/null 2>&1; then
		_emit_project_dir_labels "$programming_dir" "$created_dir" "$checkout_dir" | python3 -c '
import sys, os
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    label, _, path = line.partition("\t")
    d = path[:-1] if path.endswith("/") else path
    git = d + "/.git"
    try:
        if os.path.exists(git):
            mtime = int(os.stat(git).st_mtime)
        elif os.path.exists(d):
            mtime = int(os.stat(d).st_mtime)
        else:
            mtime = 0
    except OSError:
        mtime = 0
    sys.stdout.write("%d\t%s\t%s\n" % (mtime, label, path))
'
	else
		# Resolve the stat flavor once in THIS shell so the per-entry
		# "$(_recency_mtime ...)" subshells inherit the cached _STAT_MTIME_FMT
		# instead of re-detecting it (an extra stat fork) on every entry.
		_stat_mtime / >/dev/null 2>&1
		local label path
		while IFS=$'\t' read -r label path; do
			printf '%s\t%s\t%s\n' "$(_recency_mtime "$path")" "$label" "$path"
		done < <(_emit_project_dir_labels "$programming_dir" "$created_dir" "$checkout_dir")
	fi
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
PANE_TOOLS=(nvim opencode storecode gh-dash empty)

# Per-project pane-tool memory: one "<project_dir>\t<tool>" line per project.
# Alt p saves a project's tool when it opens it and floats it first in that
# project's picker next time. Alt ] does NOT read this map -- it always opens
# the repo's AI agent. Defaults to ~/.pane_tool_by_project; overridable for tests.
PANE_TOOL_MAP="${PANE_TOOL_MAP:-$HOME/.pane_tool_by_project}"

# Remember $tool as the pane tool last used for project $dir, replacing any
# prior entry so each project keeps exactly one line. Map defaults to
# PANE_TOOL_MAP. No-op (non-zero) without both a tool and a dir.
save_pane_tool() {
	local tool="$1" dir="$2" map="${3:-$PANE_TOOL_MAP}"
	[[ -n "$tool" && -n "$dir" ]] || return 1
	local tmp
	tmp="$(mktemp)"
	[[ -f "$map" ]] && awk -F'\t' -v d="$dir" '$1 != d' "$map" >"$tmp"
	printf '%s\t%s\n' "$dir" "$tool" >>"$tmp"
	mv "$tmp" "$map"
}

# Resolve the pane tool last used for project $dir (saved by save_pane_tool).
# Prints it on stdout; non-zero *silently* when the dir is blank, the map is
# missing, or nothing is recorded for it so the caller can fall back to a default.
last_pane_tool() {
	local dir="$1" map="${2:-$PANE_TOOL_MAP}"
	[[ -n "$dir" && -s "$map" ]] || return 1
	local tool
	tool="$(awk -F'\t' -v d="$dir" '$1 == d { v = $2 } END { if (v != "") print v }' "$map")"
	[[ -n "$tool" ]] || return 1
	printf '%s' "$tool"
}

# fzf-pick which program to open in a new stacked pane — one of nvim, opencode,
# storecode, gh-dash, or empty (a plain shell). The tool last used for project
# $dir floats to the top so repeat use is a single Enter. Prints the choice on
# stdout; non-zero if cancelled. Requires fzf.
select_pane_tool() {
	local dir="$1" map="${2:-$PANE_TOOL_MAP}"
	local last_sel=""
	[[ -n "$dir" ]] && last_sel="$(last_pane_tool "$dir" "$map" 2>/dev/null || true)"

	local selected
	selected="$(reorder_last_first "$last_sel" "${PANE_TOOLS[@]}" | fzf --prompt="Open: ")" || return 1
	[[ -z "$selected" ]] && return 1
	printf '%s' "$selected"
}

# Parse a `zellij action dump-layout` KDL (read from stdin) and print the
# absolute cwd of the single globally-focused leaf pane. The dump emits a
# layout-level base `cwd "<abs>"` (space form) plus per-pane `cwd="<rel-or-abs>"`
# (attribute form); exactly one leaf `pane ... focus=true ...` is the focused
# pane. A pane cwd is resolved relative to the base unless it is already
# absolute. Prints nothing and returns non-zero when no focused pane carries a
# cwd. Pure text munging — no zellij call — so it is unit-testable.
_focused_pane_dir_from_layout() {
	awk '
	{
		# Base cwd: first layout-level `cwd "<abs>"` (space form). A pane line
		# starts with "pane", so this never matches a per-pane attribute cwd.
		if (!have_base && match($0, /^[[:space:]]*cwd "[^"]*"/)) {
			s = substr($0, RSTART, RLENGTH)
			sub(/^[[:space:]]*cwd "/, "", s)
			sub(/"$/, "", s)
			base = s
			have_base = 1
		}
		# Focused pane: first line that is a `pane`, carries focus=true, and has
		# a cwd="..." attribute (the focused tab line also has focus=true but
		# starts with "tab"). Lock onto it so a matched-but-unextractable line
		# returns non-zero instead of falling through to a later pane.
		if (!seen_pane && $0 ~ /focus=true/ && $0 ~ /^[[:space:]]*pane[[:space:]]/ && $0 ~ /cwd="/) {
			seen_pane = 1
			# Greedy `.*` picks the LAST ` cwd="` on the line (matches sed).
			if (match($0, /.*[[:space:]]cwd="/)) {
				rest = substr($0, RLENGTH + 1)
				q = index(rest, "\"")
				if (q > 1) {
					pane = substr(rest, 1, q - 1)
					have_pane = 1
				}
			}
		}
	}
	END {
		if (!have_pane) exit 1
		if (pane ~ /^\//) {
			printf "%s", pane
		} else if (have_base && base != "") {
			sub(/\/$/, "", base)
			printf "%s/%s", base, pane
		} else {
			printf "%s", pane
		}
	}
	'
}

# Print the absolute cwd of the VISIBLE project pane from a zellij dump-layout on
# stdin: the first expanded=true leaf pane in the focused tab whose command is
# not an agent (opencode/storecode) -- the project shown in the editor column,
# which is what Alt ] should target. Unlike the focused pane it is found
# with no move-focus even when focus sits on the agent pane. A pane with no
# command attribute is a plain shell and counts as non-agent. Prints nothing and
# returns non-zero when no such pane exists. Pure text munging -- no zellij call
# -- so it is unit-testable.
_visible_project_dir_from_layout() {
	awk '
	{
		# Base cwd: first layout-level `cwd "<abs>"` (space form). A pane line
		# starts with "pane", so this never matches a per-pane attribute cwd.
		if (!have_base && match($0, /^[[:space:]]*cwd "[^"]*"/)) {
			s = substr($0, RSTART, RLENGTH)
			sub(/^[[:space:]]*cwd "/, "", s)
			sub(/"$/, "", s)
			base = s
			have_base = 1
		}
		# Track the focused tab: a `tab ... focus=true` line opens the focused
		# region and the next `tab` line (a background tab) closes it. Panes
		# are only considered inside the focused tab, since the visible editor
		# pane is not itself focus=true.
		if ($0 ~ /^[[:space:]]*tab[[:space:]]/) {
			in_focus_tab = ($0 ~ /focus=true/) ? 1 : 0
		}
		# Visible project pane: first expanded=true `pane` with a cwd in the
		# focused tab whose command is not an agent. Agents are opencode,
		# storecode, and the real exec path storecode runs as
		# (~/.storecode/lib/claude, what zellij actually records) -- the last
		# clause stops that agent dir leaking through as if it were the editor
		# pane. Lock onto the first match so a later pane cannot override it.
		if (!seen_pane && in_focus_tab && $0 ~ /^[[:space:]]*pane[[:space:]]/ && $0 ~ /expanded=true/ && $0 ~ /cwd="/ && $0 !~ /command="opencode"/ && $0 !~ /command="storecode"/ && $0 !~ /command="[^"]*\.storecode\//) {
			seen_pane = 1
			# Greedy `.*` picks the LAST ` cwd="` on the line (matches sed).
			if (match($0, /.*[[:space:]]cwd="/)) {
				rest = substr($0, RLENGTH + 1)
				q = index(rest, "\"")
				if (q > 1) {
					pane = substr(rest, 1, q - 1)
					have_pane = 1
				}
			}
		}
	}
	END {
		if (!have_pane) exit 1
		if (pane ~ /^\//) {
			printf "%s", pane
		} else if (have_base && base != "") {
			sub(/\/$/, "", base)
			printf "%s/%s", base, pane
		} else {
			printf "%s", pane
		}
	}
	'
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

# Print the absolute cwd of the VISIBLE project pane -- the expanded, non-agent
# leaf pane in the focused tab (see _visible_project_dir_from_layout). This is
# the project the user is viewing in the editor column, which is what Alt ] should open an agent for. Read straight from dump-layout with no
# move-focus, so it stays correct even when focus is on the agent pane. Returns
# non-zero *silently* when not inside a zellij session, when dump-layout fails,
# or when the resolved path is not an existing directory -- so callers can fall
# back to current_pane_dir / a picker.
visible_project_dir() {
	[[ -n "${ZELLIJ:-}" ]] || return 1
	local dir
	dir="$(zellij action dump-layout 2>/dev/null | _visible_project_dir_from_layout)" || return 1
	[[ -n "$dir" && -d "$dir" ]] || return 1
	printf '%s' "$dir"
}

# Parse a `zellij action dump-layout` KDL (read from stdin) and print the NAME
# of the VISIBLE project pane: the first expanded=true `pane` in the focused tab
# whose command is nvim. nvim renames its own pane to the basename of its cwd on
# every DirChanged (see src/nvim/lua/custom/actions/zellij_pane.lua), so this
# name tracks the worktree the user is viewing even after an in-place worktree
# switch has left the pane's recorded cwd pointing at the original repo -- which
# is exactly the case the cwd-based resolvers get wrong. Prints nothing and
# returns non-zero when no such pane exists. Pure text munging -- no zellij call
# -- so it is unit-testable.
_visible_project_name_from_layout() {
	awk '
	{
		# Track the focused tab: a `tab ... focus=true` line opens it and the
		# next `tab` line (a background tab) closes it. Panes only count inside
		# the focused tab.
		if ($0 ~ /^[[:space:]]*tab[[:space:]]/) {
			in_focus_tab = ($0 ~ /focus=true/) ? 1 : 0
		}
		# Visible project pane: the first expanded=true nvim `pane` carrying a
		# name in the focused tab. Lock onto the first match.
		if (!seen_pane && in_focus_tab && $0 ~ /^[[:space:]]*pane[[:space:]]/ && $0 ~ /expanded=true/ && $0 ~ /command="nvim"/ && $0 ~ /name="/) {
			seen_pane = 1
			# Greedy `.*` picks the LAST ` name="` on the line.
			if (match($0, /.*[[:space:]]name="/)) {
				rest = substr($0, RLENGTH + 1)
				q = index(rest, "\"")
				if (q > 1) {
					name = substr(rest, 1, q - 1)
					have_name = 1
				}
			}
		}
	}
	END {
		if (!have_name) exit 1
		printf "%s", name
	}
	'
}

# Resolve a project/worktree NAME (a directory basename -- e.g. the name nvim
# gives its zellij pane, kept in sync with the worktree by rename_pane) to an
# absolute path by matching the basename of every enumerated ~/Programming
# project and wcreated/wcheckout worktree, most-recently-used first so a basename
# collision resolves to the copy the user touched last. Prints the absolute path
# and bumps its recency on a hit; returns non-zero *silently* when the name is
# blank or resolves to no existing directory so the caller can fall back. The
# three container args default to the production paths and are overridable for
# tests.
project_dir_for_name() {
	local name="$1"
	local programming_dir="${2:-$HOME/Programming}"
	local created_dir="${3:-${WCREATED_DIR:-$programming_dir/wcreated}}"
	local checkout_dir="${4:-${WCHECKOUT_DIR:-$programming_dir/wcheckout}}"
	[[ -n "$name" ]] || return 1

	local entry_path base found=""
	while IFS=$'\t' read -r _ _ entry_path; do
		base="${entry_path%/}"
		base="${base##*/}"
		if [[ "$base" == "$name" ]]; then
			found="$entry_path"
			break
		fi
	done < <(_collect_project_dir_entries "$programming_dir" "$created_dir" "$checkout_dir" | sort -t$'\t' -k1,1 -rn)

	[[ -n "$found" && -d "$found" ]] || return 1
	bump_project_recency "$found"
	printf '%s' "$found"
}

# Print the absolute dir of the VISIBLE project pane resolved BY NAME: read the
# expanded nvim pane's name from dump-layout (see
# _visible_project_name_from_layout) and resolve it to a directory (see
# project_dir_for_name). Because nvim keeps its pane name in sync with the
# worktree, this stays correct even when the pane's recorded cwd goes stale after
# an in-place worktree switch -- the case visible_project_dir / current_pane_dir
# get wrong. Returns non-zero *silently* when not inside a zellij session, when
# dump-layout fails, when no visible nvim pane exists, or when the name resolves
# to no directory -- so callers fall back to the cwd-based resolvers.
visible_project_dir_by_name() {
	[[ -n "${ZELLIJ:-}" ]] || return 1
	local name
	name="$(zellij action dump-layout 2>/dev/null | _visible_project_name_from_layout)" || return 1
	[[ -n "$name" ]] || return 1
	project_dir_for_name "$name"
}

# Open a new stacked zellij pane rooted at $1 running tool $2 (one of
# PANE_TOOLS). "empty" opens a plain shell pane; every other tool runs the tool
# and then drops into an interactive zsh in $target_dir when the tool exits, so
# the pane stays usable instead of vanishing. The focused tab is renamed after
# the project folder; callers should reindex tab names afterward.
open_tool_pane() {
	local target_dir="$1"
	local tool="$2"

	if [[ "$tool" == "empty" ]]; then
		zellij action new-pane --cwd "$target_dir" --stacked
	else
		# Run the tool, then `exec zsh` so exiting it drops into an
		# interactive shell in the project dir instead of closing the pane
		# (no --close-on-exit). `zsh -c` keeps `tool; exec zsh` as one argv.
		zellij action new-pane --cwd "$target_dir" --stacked -- \
			zsh -c "$tool; exec zsh -i"
	fi

	zellij action rename-tab "$(basename "$target_dir")"
}

# --- Project sidebar launcher (Alt p) ----------------------------------------
# Alt p opens the 30% chosen-tool / 70% nvim SPLIT LAYOUT (the sidebar) in a new
# tab -- not a single stacked pane. render_sidebar_layout is the one pure piece
# (no fzf/zellij) so it is unit-tested in tests/test_sidebar_layout.zsh.

# Render a throwaway copy of the sidebar layout with $1 as the left sidebar
# pane's command, printing the path to the freshly-created temp layout (in its
# own temp dir) on stdout. The base structure stays defined once in
# layouts/opencode-sidebar.kdl; only the sidebar's command is swapped. "empty"
# yields a plain shell pane (the command is dropped, so its close_on_exit goes
# with it). $2 overrides the source layout for tests (defaults to the installed
# copy under ~/.config). Returns non-zero WITHOUT creating anything when the
# source layout is missing or $1 is blank, so a bad tool never reaches a
# spawned pane.
render_sidebar_layout() {
	local tool="$1"
	local layout_src="${2:-$HOME/.config/zellij/layouts/opencode-sidebar.kdl}"
	[[ -n "$tool" ]] || return 1
	[[ -f "$layout_src" ]] || return 1
	local out_dir out
	out_dir="$(mktemp -d)"
	out="$out_dir/opencode-sidebar.kdl"
	if [[ "$tool" == "empty" ]]; then
		sed 's|pane command="opencode" close_on_exit=true|pane|' "$layout_src" >"$out"
	else
		sed "s|pane command=\"opencode\"|pane command=\"$tool\"|" "$layout_src" >"$out"
	fi
	printf '%s' "$out"
}

# --- Alt ] repo -> AI-agent routing ------------------------------------------
# open_ai_chat.sh (Alt ]) always opens an AI agent, and the RIGHT agent
# depends on the repo: Jimmy's personal repos use opencode while everything
# else — work repos, and anything with an unknown or missing origin — uses
# storecode (the GCP-authed internal build from src/install/storecode.sh).
# These helpers pick the agent from the repo's git origin owner so Alt ] never
# opens the wrong one.

# GitHub owners whose repos open opencode instead of storecode, matched
# case-insensitively against the origin remote's owner. Everything not listed
# here (including an unknown or missing owner) opens storecode. Set
# PERSONAL_AGENT_ORGS before sourcing this file to override it (e.g. in tests).
if [[ -z "${PERSONAL_AGENT_ORGS+set}" ]]; then
	PERSONAL_AGENT_ORGS=(jimmytrandev)
fi

# Print the owner (the "<owner>" in <owner>/<repo>) parsed from a git remote URL:
# scp form (git@host:owner/repo.git), ssh:// and https:// URLs, with or without a
# trailing ".git". Returns non-zero *silently* for an empty or owner-less URL so
# callers can fall back to a default. Pure text munging (no git call), so it is
# unit-testable.
_owner_from_remote_url() {
	local url="$1"
	[[ -n "$url" ]] || return 1
	url="${url%.git}"
	url="${url%/}"
	[[ "$url" == */* ]] || return 1
	local owner_seg="${url%/*}"    # drop "/<repo>"
	local owner="${owner_seg##*/}" # strip scheme/host for URL forms
	owner="${owner##*:}"           # strip "git@host:" for scp form
	[[ -n "$owner" ]] || return 1
	printf '%s' "$owner"
}

# Print the GitHub owner of $dir's origin remote (see _owner_from_remote_url).
# Returns non-zero *silently* when $dir has no origin remote (or is not a repo).
github_remote_owner() {
	local dir="$1" url
	url="$(git -C "$dir" remote get-url origin 2>/dev/null)" || return 1
	_owner_from_remote_url "$url"
}

# Map a GitHub owner to the AI agent its repos should open: "opencode" when the
# owner is one of PERSONAL_AGENT_ORGS (case-insensitive), else "storecode". An
# empty or unknown owner yields "storecode". Always prints one of the two agents.
# Lowercases with tr so it behaves the same under bash launchers and zsh tests.
agent_for_owner() {
	local owner="$1"
	[[ -n "$owner" ]] || { printf 'storecode'; return 0; }
	local o personal p
	o="$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')"
	for personal in "${PERSONAL_AGENT_ORGS[@]}"; do
		p="$(printf '%s' "$personal" | tr '[:upper:]' '[:lower:]')"
		[[ "$o" == "$p" ]] && { printf 'opencode'; return 0; }
	done
	printf 'storecode'
}

# Print the AI agent $dir's repo should open: opencode for a personal repo (its
# origin owner is in PERSONAL_AGENT_ORGS), else storecode (including a repo with
# no origin). Always prints one of the two agents.
resolve_repo_agent() {
	local dir="$1" owner
	owner="$(github_remote_owner "$dir" 2>/dev/null || true)"
	agent_for_owner "$owner"
}

# Print the argv that makes AI agent $1 auto-run the /commit command, one token
# per line so a caller reads it into an array. The Alt c launcher
# (open_ai_commit.sh) appends this after the agent name to open the agent with
# /commit already submitted. opencode takes an initial prompt via its --prompt
# flag; storecode (an Enterprise Claude Code wrapper) has no such flag and
# instead passes positional args straight through to Claude Code as the prompt,
# so the two agents need different argv. Any non-opencode agent (storecode, and
# an unknown/empty name) uses the positional form -- the same conservative
# default direction as agent_for_owner. Pure (no fzf/zellij), so it is
# unit-testable in tests/test_agent_commit_argv.zsh.
agent_commit_argv() {
	local agent="$1"
	if [[ "$agent" == "opencode" ]]; then
		printf '%s\n' "--prompt" "/commit"
	else
		printf '%s\n' "/commit"
	fi
}
