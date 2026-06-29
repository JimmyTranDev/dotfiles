#!/bin/zsh

# worktree diff — show a git diff for managed worktrees without cd-ing into them.
#
# Every other diff helper in this repo (the `d` commit picker, `too` /
# git_diff_base.sh) only acts on the *current* repo. This command lets you diff a
# worktree you are not standing in, or compare two worktrees against each other,
# by picking them from the wcreated/wcheckout containers.
#
#   worktree diff                    pick 1-2 worktrees via fzf
#   worktree diff <name|path>        diff that worktree's branch vs its base
#   worktree diff <a> <b>            diff branch A vs branch B (same repo)
#   worktree diff <a> -- --stat      pass extra flags through to `git diff`
#
# Selection rules:
#   1 worktree  -> git -C <wt> diff <base>...HEAD   ("what this branch added")
#   2 worktrees -> git -C <wt> diff <branchA>...<branchB>   (same repo only)
#
# Read-only: never fetches or mutates git state. The helpers below are pure and
# deterministic so they can be unit-tested without a real git repo
# (see etc/scripts/tests/test_worktree_diff.zsh).

# Echo the `git diff` range for a diff mode; return 1 on an unknown mode.
#   single <base>             -> "<base>...HEAD"
#   pair   <branchA> <branchB> -> "<branchA>...<branchB>"
# Three-dot (...) so the diff is taken from the branches' merge base, matching
# the PR / `too` "what changed since we diverged" semantics.
_worktree_diff_range() {
	local mode="$1"
	case "$mode" in
	single)
		[[ -n "$2" ]] || return 1
		echo "${2}...HEAD"
		;;
	pair)
		[[ -n "$2" && -n "$3" ]] || return 1
		echo "${2}...${3}"
		;;
	*)
		return 1
		;;
	esac
}

# Echo a worktree's main repo path by parsing its ".git" gitdir pointer; return
# 1 when it isn't a worktree pointer. Parsed inline (rather than via the core
# helpers) to stay pure and testable with fixture pointer files.
#   <repo>/.git/worktrees/<name>  ->  <repo>
_worktree_diff_main_repo() {
	local wt="$1" line
	[[ -n "$wt" && -f "$wt/.git" ]] || return 1
	line=$(head -n1 "$wt/.git" 2>/dev/null)
	[[ "$line" == gitdir:\ * ]] || return 1
	echo "${${line#gitdir: }:h:h:h}"
}

# Resolve a worktree selector (a basename under the containers, or a direct
# path) to an absolute worktree path that carries a ".git" gitdir pointer.
# Echoes the path and returns 0 on success; returns 1 when nothing matches.
# Pure: touches the filesystem only, never git.
_worktree_diff_resolve_name() {
	local sel="$1" created_dir="$2" checkout_dir="$3"
	local candidate
	for candidate in "$sel" "$created_dir/$sel" "$checkout_dir/$sel"; do
		[[ -n "$candidate" && -d "$candidate" ]] || continue
		[[ -f "$candidate/.git" ]] || continue
		grep -q "^gitdir:" "$candidate/.git" 2>/dev/null || continue
		echo "${candidate:A}"
		return 0
	done
	return 1
}

# Return 0 when both worktrees resolve to the same main repository, echoing that
# repo path; return 1 otherwise (including a worktree that can't be resolved).
_worktree_diff_same_repo() {
	local repo_a repo_b
	repo_a=$(_worktree_diff_main_repo "$1") || return 1
	repo_b=$(_worktree_diff_main_repo "$2") || return 1
	[[ -n "$repo_a" && "$repo_a" == "$repo_b" ]] || return 1
	echo "$repo_a"
}

# Diff a single worktree's branch against its base branch (develop/main/master).
_worktree_diff_single() {
	local wt="$1"
	shift
	local branch base range
	branch=$(git -C "$wt" branch --show-current 2>/dev/null)
	base=$(find_base_branch "$wt") || {
		print_color red "Error: no base branch (develop/main/master) in $(basename "$wt")"
		return 1
	}
	if [[ -n "$branch" && "$branch" == "$base" ]]; then
		print_color yellow "$(basename "$wt") is on base '$base' — nothing to diff"
		return 0
	fi
	range=$(_worktree_diff_range single "$base")
	print_color cyan "Diff: ${branch:-HEAD} vs $base   [$(basename "$wt")]  ($range)"
	print -r -- "----------------------------------------"
	git -C "$wt" diff "$range" "$@"
}

# Diff two worktrees' branches against each other; both must be in the same repo.
_worktree_diff_pair() {
	local wt_a="$1" wt_b="$2"
	shift 2
	local repo branch_a branch_b range
	if ! repo=$(_worktree_diff_same_repo "$wt_a" "$wt_b"); then
		print_color red "Error: worktrees are not in the same repository — cannot diff across repos"
		print_color yellow "  A: $wt_a"
		print_color yellow "  B: $wt_b"
		return 1
	fi
	branch_a=$(git -C "$wt_a" branch --show-current 2>/dev/null)
	branch_b=$(git -C "$wt_b" branch --show-current 2>/dev/null)
	if [[ -z "$branch_a" || -z "$branch_b" ]]; then
		print_color red "Error: both worktrees must be on a named branch (no detached HEAD)"
		return 1
	fi
	range=$(_worktree_diff_range pair "$branch_a" "$branch_b")
	print_color cyan "Diff: $branch_a vs $branch_b   [$(basename "$repo")]  ($range)"
	print -r -- "----------------------------------------"
	git -C "$wt_a" diff "$range" "$@"
}

# Let the user pick 1-2 worktrees with fzf, echoing one absolute worktree path
# per line. Returns 1 if fzf is missing, there are no worktrees, or nothing was
# picked.
_worktree_diff_pick() {
	local created_dir="$1" checkout_dir="$2"
	check_tool fzf || return 1

	local entries
	entries=$(_worktree_list_entries "$created_dir" "$checkout_dir")
	if [[ -z "$entries" ]]; then
		print_color yellow "No worktrees found in $created_dir or $checkout_dir" >&2
		return 1
	fi

	# Render "name<TAB>repo<TAB>branch<TAB>path"; fzf shows the first three
	# columns and carries the hidden path so we can map the choice back.
	local selected line
	selected=$(print -r -- "$entries" |
		awk -F'\t' '{printf "%s\t%s\t%s\t%s\n", $2, $3, $4, $8}' |
		fzf --multi --with-nth=1,2,3 --delimiter='\t' \
			--prompt="Diff worktree(s) [TAB to pick 2] > " --height=40% --reverse) || return 1
	[[ -n "$selected" ]] || return 1

	while IFS= read -r line; do
		[[ -n "$line" ]] || continue
		print -r -- "${line##*$'\t'}"
	done <<<"$selected"
}

# `worktree diff` entry point — see the file header for the full contract.
cmd_diff() {
	check_tool git || return 1

	local created_dir="${WCREATED_DIR:-$HOME/Programming/wcreated}"
	local checkout_dir="${WCHECKOUT_DIR:-$HOME/Programming/wcheckout}"

	# Split args: worktree selectors before `--`, git-diff passthrough after it.
	local -a selectors passthrough
	local seen_dd=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			print_color cyan "Usage: worktree diff [worktree ...] [-- <git diff args>]"
			print_color cyan "  No args:     pick 1-2 worktrees via fzf."
			print_color cyan "  1 worktree:  diff its branch against its base (<base>...HEAD)."
			print_color cyan "  2 worktrees: diff their branches (<branchA>...<branchB>); same repo only."
			print_color cyan "  A worktree is a name under wcreated/wcheckout, or a path."
			print_color cyan "  Extra git diff flags go after '--', e.g. worktree diff alpha -- --stat"
			return 0
			;;
		--)
			seen_dd=true
			shift
			;;
		*)
			if [[ "$seen_dd" == true ]]; then
				passthrough+=("$1")
			else
				selectors+=("$1")
			fi
			shift
			;;
		esac
	done

	# Resolve target worktree paths from selectors, or fall back to an fzf pick.
	local -a targets
	if [[ ${#selectors[@]} -gt 0 ]]; then
		local sel resolved
		for sel in "${selectors[@]}"; do
			if ! resolved=$(_worktree_diff_resolve_name "$sel" "$created_dir" "$checkout_dir"); then
				print_color red "Error: no worktree matching '$sel' under $created_dir or $checkout_dir"
				return 1
			fi
			targets+=("$resolved")
		done
	else
		local picked
		picked=$(_worktree_diff_pick "$created_dir" "$checkout_dir") || {
			print_color yellow "No worktree selected"
			return 1
		}
		local line
		while IFS= read -r line; do
			[[ -n "$line" ]] && targets+=("$line")
		done <<<"$picked"
	fi

	if [[ ${#targets[@]} -eq 0 ]]; then
		print_color red "Error: no worktrees selected"
		return 1
	fi
	if [[ ${#targets[@]} -gt 2 ]]; then
		print_color red "Error: select at most 2 worktrees (got ${#targets[@]})"
		return 1
	fi

	if [[ ${#targets[@]} -eq 1 ]]; then
		_worktree_diff_single "${targets[1]}" "${passthrough[@]}"
	else
		_worktree_diff_pair "${targets[1]}" "${targets[2]}" "${passthrough[@]}"
	fi
}
