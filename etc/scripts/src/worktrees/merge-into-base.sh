#!/bin/zsh

# merge-into-base.sh — concurrency-safe "merge a worktree's branch into its base"
# for /implement-worktree Phase 7. When several worktree runs finish in parallel
# they all try to merge into the SAME base branch in the SAME main repo, which a
# repo cannot do at once (one checked-out branch / one in-progress merge), and
# concurrent pushes race. This serializes those merges with an atomic mkdir lock
# (macOS has no flock), WAITS when another merge is already running, REBASES the
# branch onto the freshened base first (linear history; conflicts surface in the
# worktree), retries on push races, and — on a conflict — hands the caller a
# resolvable state:
#   - a REBASE conflict is left in the worktree with the lock RELEASED; resolve
#     it, `git rebase --continue`, then re-run `merge`.
#   - a MERGE/push conflict is left in the base repo with the lock RETAINED;
#     resolve it, commit, then `finalize`.
#
# Usage:
#   merge-into-base.sh merge    --worktree <path> [--timeout S] [--poll S] [--stale S] [--no-push]
#   merge-into-base.sh finalize --worktree <path> [--no-push]
#   merge-into-base.sh abort    --worktree <path>
#
# Exit codes:
#   0  merged (and pushed) / finalized cleanly; lock released
#   2  conflict — either a rebase conflict in the worktree (lock RELEASED, re-run
#      `merge` after `rebase --continue`) or a merge/push conflict in the base
#      repo (lock RETAINED, run `finalize` after committing the resolution)
#   3  precondition failed (dirty base repo OR dirty worktree, foreign/abandoned
#      merge, bad branch)
#   4  timed out waiting for the serialization lock
#   1  usage or other error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/../../utils/worktree_core.sh"

# Tunables (flags override; env overrides the built-in default).
WT_MERGE_TIMEOUT="${WT_MERGE_TIMEOUT:-1800}"   # max seconds a waiter blocks on the lock
WT_MERGE_POLL="${WT_MERGE_POLL:-5}"            # seconds between polls while waiting
WT_MERGE_STALE="${WT_MERGE_STALE:-3600}"       # a lock older than this is reclaimed
WT_READY_TIMEOUT=120                           # seconds to wait for MERGE_HEAD/index.lock to clear

# Process-global state used by the exit/signal traps.
LOCK_DIR=""    # set once we own the lock in THIS process; "" while only waiting
KEEP_LOCK=0    # when 1, the exit trap leaves the lock for the caller (conflict)
REPO=""        # main repo we are operating on, for the traps

# ---------------------------------------------------------------------------
# Lock primitives (atomic mkdir; portable to macOS where flock is absent)
# ---------------------------------------------------------------------------

# Remove a lock directory. Idempotent. Defaults to the lock this process owns.
lock_release() {
	local lock="${1:-$LOCK_DIR}"
	[[ -n "$lock" && -d "$lock" ]] && rm -rf "$lock" 2>/dev/null
	[[ "$lock" == "$LOCK_DIR" ]] && LOCK_DIR=""
	return 0
}

# Acquire the per-repo merge lock, waiting until it is free (or reclaiming it if
# the current holder is stale). Returns 0 holding the lock, or 4 on timeout.
lock_acquire() {
	local repo="$1" wt="$2" timeout="$3" poll="$4" stale="$5"
	local lock="$repo/.git/wt-merge.lock"
	local deadline=$(( $(date +%s) + timeout ))
	local owner_ts now holder

	while true; do
		if mkdir "$lock" 2>/dev/null; then
			{
				print -r -- "owner=$wt"
				print -r -- "pid=$$"
				print -r -- "ts=$(date +%s)"
			} > "$lock/info" 2>/dev/null
			LOCK_DIR="$lock"
			return 0
		fi

		# Held by someone else — atomically STEAL it if it looks abandoned.
		# Rename is atomic on one filesystem, so at most one waiter can reclaim
		# a given stale lock (the source vanishes for everyone else); losers and
		# the winner all re-loop and race mkdir normally. This avoids the
		# read-then-rm race where two waiters could both delete and double-own.
		owner_ts=$(sed -n 's/^ts=//p' "$lock/info" 2>/dev/null)
		now=$(date +%s)
		if [[ -n "$owner_ts" ]] && (( now - owner_ts > stale )); then
			if mv "$lock" "$lock.stale.$$" 2>/dev/null; then
				print_color yellow "  Reclaiming stale merge lock (age $((now - owner_ts))s) in $(basename "$repo")"
				rm -rf "$lock.stale.$$" 2>/dev/null
			fi
			continue
		fi

		if (( now >= deadline )); then
			print_color red "  Timed out after ${timeout}s waiting for the merge lock in $(basename "$repo")"
			return 4
		fi

		holder=$(sed -n 's/^owner=//p' "$lock/info" 2>/dev/null)
		print_color cyan "  Another merge is in progress in $(basename "$repo") — waiting${holder:+ (held by $(basename "$holder"))}..."
		sleep "$poll"
	done
}

# Wait for the repo to be free of an in-progress merge / transient index lock.
# Because we already hold our lock, a lingering MERGE_HEAD is a foreign or
# abandoned merge we must not clobber. Returns 0 when ready, 3 if it never clears.
wait_for_ready_base() {
	local repo="$1" poll="$2"
	local deadline=$(( $(date +%s) + WT_READY_TIMEOUT ))
	while true; do
		local busy=0
		git -C "$repo" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 && busy=1
		[[ -f "$repo/.git/index.lock" ]] && busy=1
		(( busy )) || return 0
		if (( $(date +%s) >= deadline )); then
			print_color red "  Base repo is stuck mid-merge (foreign/abandoned). Resolve it first: $repo"
			return 3
		fi
		sleep "$poll"
	done
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Echo the main repo path for a worktree, or return 1.
resolve_repo() {
	local wt="$1" repo
	repo=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
	repo="${repo:h}"
	[[ -n "$repo" && -d "$repo" ]] || return 1
	echo "$repo"
}

# Push <base> to origin, integrating any concurrent advance of the remote base
# on a non-fast-forward rejection. Returns 0 pushed, 2 conflict (lock retained),
# 1 exhausted. Skipped entirely by the caller when --no-push is set.
push_with_retry() {
	local repo="$1" base="$2" attempts=5 i
	for (( i = 1; i <= attempts; i++ )); do
		if git -C "$repo" push origin "$base" >/dev/null 2>&1; then
			print_color green "  Pushed '$base' to origin."
			return 0
		fi
		print_color yellow "  Push of '$base' rejected (attempt $i/$attempts) — integrating remote and retrying..."
		git -C "$repo" fetch origin "$base" 2>/dev/null || true
		if ! git -C "$repo" merge --no-ff --no-edit "origin/$base" >/dev/null 2>&1; then
			print_color red "  Conflict integrating remote '$base' during push."
			KEEP_LOCK=1
			return 2
		fi
	done
	print_color red "  Could not push '$base' after $attempts attempts."
	return 1
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

# All non-conflict exits release the lock via the EXIT trap; the conflict paths
# set KEEP_LOCK=1 so the trap leaves the in-progress merge for the caller.
do_merge() {
	local wt="$1" timeout="$2" poll="$3" stale="$4" push="$5"
	local repo branch base rc

	repo=$(resolve_repo "$wt") || { print_color red "Cannot resolve main repo from worktree: $wt"; return 1; }
	branch=$(git -C "$wt" branch --show-current 2>/dev/null)
	[[ -n "$branch" ]] || { print_color red "Worktree has a detached HEAD: $wt"; return 1; }
	base=$(find_base_branch "$repo")
	[[ "$base" != "unknown" ]] || { print_color red "No base branch (develop/main/master) in $repo"; return 1; }
	[[ "$branch" != "$base" ]] || { print_color red "Branch '$branch' is the base branch — nothing to merge."; return 1; }

	REPO="$repo"
	lock_acquire "$repo" "$wt" "$timeout" "$poll" "$stale" || return $?   # 4 on timeout, lock not held

	wait_for_ready_base "$repo" "$poll" || return 3

	# Never merge onto a base repo that has unrelated uncommitted work.
	if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then
		print_color red "  Base repo has uncommitted changes — commit or stash them first: $repo"
		return 3
	fi

	if [[ "$(git -C "$repo" branch --show-current 2>/dev/null)" != "$base" ]]; then
		if ! git -C "$repo" switch "$base" 2>/dev/null && ! git -C "$repo" checkout "$base" 2>/dev/null; then
			print_color red "  Could not switch to '$base' (checked out elsewhere?): $repo"
			return 3
		fi
	fi

	# Bring local base up to its remote first (best effort — tolerate offline).
	git -C "$repo" fetch origin "$base" 2>/dev/null || true
	git -C "$repo" merge --ff-only "origin/$base" 2>/dev/null || true

	# Rebase the feature branch onto the freshened base BEFORE merging, so the
	# integration is linear and any conflict surfaces here — in the worktree,
	# off-lock — rather than as a merge commit in the shared base repo. A dirty
	# worktree cannot be rebased, so refuse it up front.
	if [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]; then
		print_color red "  Worktree has uncommitted changes — commit or stash them first: $wt"
		return 3
	fi
	print_color cyan "Rebasing '$branch' onto '$base' before merge..."
	if ! git -C "$wt" rebase "$base" >/dev/null 2>&1; then
		print_color red "  CONFLICT rebasing '$branch' onto '$base'."
		local rf
		while IFS= read -r rf; do
			[[ -n "$rf" ]] && print_color red "    conflict: $rf"
		done < <(git -C "$wt" diff --name-only --diff-filter=U 2>/dev/null)
		print_color yellow "  Rebase left in progress in the worktree: $wt"
		print_color yellow "  Resolve (preserve intent), then continue the rebase:"
		print_color yellow "    git -C '$wt' add -A && git -C '$wt' rebase --continue"
		print_color yellow "  then re-run the merge:"
		print_color yellow "    merge-into-base.sh merge --worktree '$wt'"
		# B2.5: do NOT keep the lock — the conflict lives in the worktree, so
		# resolution happens off-lock and the re-run re-acquires it cleanly.
		return 2
	fi

	print_color cyan "Merging '$branch' -> '$base' in $(basename "$repo")..."
	if git -C "$repo" merge --no-ff --no-edit "$branch" >/dev/null 2>&1; then
		print_color green "  Merged cleanly into '$base'."
		if [[ "$push" == true ]]; then
			push_with_retry "$repo" "$base"; rc=$?
			if (( rc == 2 )); then
				print_color yellow "  Merge left in progress in: $repo (resolve, commit, then 'finalize')"
				return 2
			elif (( rc != 0 )); then
				return 1
			fi
		fi
		return 0
	fi

	# Real content conflict — hand it to the caller with the lock RETAINED.
	print_color red "  CONFLICT merging '$branch' into '$base'."
	local f
	while IFS= read -r f; do
		[[ -n "$f" ]] && print_color red "    conflict: $f"
	done < <(git -C "$repo" diff --name-only --diff-filter=U 2>/dev/null)
	print_color yellow "  Merge left in progress in: $repo"
	print_color yellow "  Resolve (preserve both sides), commit, then:"
	print_color yellow "    merge-into-base.sh finalize --worktree '$wt'"
	KEEP_LOCK=1
	return 2
}

# Push the now-resolved merge and release the lock. Run AFTER the caller has
# committed the conflict resolution. Runs in a fresh process, so the lock is
# referenced by path rather than $LOCK_DIR (the exit trap is a no-op here).
do_finalize() {
	local wt="$1" push="$2"
	local repo base rc
	repo=$(resolve_repo "$wt") || { print_color red "Cannot resolve main repo from worktree: $wt"; return 1; }
	REPO="$repo"
	base=$(find_base_branch "$repo")

	if git -C "$repo" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
		print_color red "  A merge is still in progress in $repo — commit the resolved merge first."
		return 2
	fi

	if [[ "$push" == true ]]; then
		push_with_retry "$repo" "$base"; rc=$?
		(( rc == 2 )) && return 2
		(( rc != 0 )) && return 1
	fi

	lock_release "$repo/.git/wt-merge.lock"
	print_color green "  Finalized merge into '$base' in $(basename "$repo")."
	return 0
}

# Abort an in-progress merge and release the lock (escape hatch).
do_abort() {
	local wt="$1" repo
	repo=$(resolve_repo "$wt") || { print_color red "Cannot resolve main repo from worktree: $wt"; return 1; }
	git -C "$wt" rebase --abort 2>/dev/null || true
	git -C "$repo" merge --abort 2>/dev/null || true
	lock_release "$repo/.git/wt-merge.lock"
	print_color yellow "  Aborted any in-progress rebase/merge and released the lock in $(basename "$repo")."
	return 0
}

# Release our lock on any exit unless a conflict handed it to the caller. This
# is the single guaranteed release point, so no early return can leak the lock.
on_exit() {
	(( KEEP_LOCK )) && return
	[[ -n "$LOCK_DIR" ]] && lock_release "$LOCK_DIR"
}
trap on_exit EXIT

# Abort our own in-progress merge and free the lock when interrupted, so a
# Ctrl-C never leaves the shared repo half-merged or the lock stuck.
on_signal() {
	KEEP_LOCK=0
	if [[ -n "$LOCK_DIR" ]]; then
		[[ -n "$REPO" ]] && git -C "$REPO" merge --abort 2>/dev/null
		lock_release "$LOCK_DIR"
	fi
	exit 130
}
trap on_signal INT TERM

usage() {
	print_color cyan "Usage: merge-into-base.sh <merge|finalize|abort> --worktree <path> [options]"
	print_color cyan "  merge     Serialize, rebase the branch onto its base, merge, then push."
	print_color cyan "  finalize  Push a resolved merge and release the lock (after a conflict)."
	print_color cyan "  abort     Abort an in-progress merge and release the lock."
	print_color cyan "Options:"
	print_color cyan "  --worktree <path>  The wcreated worktree whose branch to merge (required)."
	print_color cyan "  --timeout <sec>    Max seconds to wait for the lock (default $WT_MERGE_TIMEOUT)."
	print_color cyan "  --poll <sec>       Poll interval while waiting (default $WT_MERGE_POLL)."
	print_color cyan "  --stale <sec>      Reclaim a lock older than this (default $WT_MERGE_STALE)."
	print_color cyan "  --no-push          Merge/finalize locally without pushing."
	print_color cyan "Exit: 0 ok | 2 conflict (rebase: lock freed / merge: lock kept) | 3 precondition | 4 lock timeout | 1 error"
}

main() {
	check_tool git || return 1

	local sub=""
	[[ $# -gt 0 ]] && { sub="$1"; shift; }

	local wt="" timeout="$WT_MERGE_TIMEOUT" poll="$WT_MERGE_POLL" stale="$WT_MERGE_STALE" push=true
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--worktree) wt="$2"; shift 2 ;;
		--timeout)  timeout="$2"; shift 2 ;;
		--poll)     poll="$2"; shift 2 ;;
		--stale)    stale="$2"; shift 2 ;;
		--no-push)  push=false; shift ;;
		-h | --help) usage; return 0 ;;
		*) print_color yellow "Unknown option: $1"; shift ;;
		esac
	done

	case "$sub" in
	-h | --help | "") usage; [[ -z "$sub" ]] && return 1; return 0 ;;
	esac

	[[ -n "$wt" ]] || { print_color red "Error: --worktree <path> is required"; return 1; }
	[[ -d "$wt" ]] || { print_color red "Error: worktree not found: $wt"; return 1; }
	require_git_repo "$wt" || return 1

	case "$sub" in
	merge)    do_merge "$wt" "$timeout" "$poll" "$stale" "$push" ;;
	finalize) do_finalize "$wt" "$push" ;;
	abort)    do_abort "$wt" ;;
	*) print_color red "Unknown subcommand: $sub"; usage; return 1 ;;
	esac
}

main "$@"
exit $?
