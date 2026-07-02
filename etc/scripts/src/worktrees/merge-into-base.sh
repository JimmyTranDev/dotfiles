#!/bin/zsh

# merge-into-base.sh — concurrency-safe, CHECKOUT-FREE "rebase a worktree's branch
# onto its base and advance the base onto it" for /implement-worktree Phase 7.
# When several worktree runs finish in parallel they all try to land onto the
# SAME base branch in the SAME main repo, which a repo cannot do at once, and
# concurrent pushes race. This serializes them with an atomic mkdir lock (macOS
# has no flock), WAITS when another is already running, then integrates ENTIRELY
# IN THE WORKTREE — it never checks out or mutates the base in the main repo:
#   1. rebase the branch onto the freshened base IN THE WORKTREE (linear history;
#      a rebase conflict surfaces here, off-lock),
#   2. push the rebased tip straight to origin/<base> FROM THE WORKTREE (a push
#      race is reconciled by rebasing the worktree onto the advanced remote and
#      re-pushing — still in the worktree),
#   3. advance the LOCAL <base> ref onto the rebased tip via a checkout-free
#      `update-ref` compare-and-swap (detaching the main repo's HEAD first when it
#      has <base> checked out, so the working tree is never touched — NO merge
#      commit). The main repo is left DETACHED at the old base commit, clean.
# On a conflict the caller gets a resolvable state, always IN THE WORKTREE with
# the lock RELEASED: resolve it, `git rebase --continue`, then re-run `merge`.
#
# Usage:
#   merge-into-base.sh merge    --worktree <path> [--timeout S] [--poll S] [--stale S] [--no-push]
#   merge-into-base.sh finalize --worktree <path> [--no-push]
#   merge-into-base.sh abort    --worktree <path>
#
# Exit codes:
#   0  rebased + base advanced (and pushed) / finalized cleanly; lock released
#   2  conflict — a rebase conflict in the worktree (lock RELEASED); resolve it,
#      `git rebase --continue`, then re-run `merge` (this covers both the initial
#      rebase onto the base and a push-race rebase onto the advanced remote)
#   3  precondition failed (dirty base repo OR dirty worktree, foreign/abandoned
#      merge, bad branch, or the base ref moved under the lock — retry)
#   4  timed out waiting for the serialization lock
#   1  usage or other error
#
# `finalize` remains as a manual escape hatch (push the base + release the lock),
# but the normal push race no longer strands a rebase in the main repo, so it is
# rarely needed.

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
KEEP_LOCK=0    # defensive: when 1 the exit trap keeps the lock (unused now — all conflicts are off-lock in the worktree)
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

# Push the WORKTREE's rebased tip straight to origin/<base>, integrating any
# concurrent advance of the remote base on a non-fast-forward rejection by
# REBASING the worktree branch onto the advanced remote tip — keeping history
# linear and keeping the whole operation IN THE WORKTREE (the main repo is never
# touched). The push runs from the worktree (`push origin HEAD:<base>`), so on a
# race conflict the rebase is left IN THE WORKTREE with the lock RELEASED; the
# caller returns 2 and a re-run reconciles. Returns 0 pushed, 2 push-race rebase
# conflict (lock released), 1 exhausted. Skipped entirely when --no-push is set.
push_with_retry() {
	local wt="$1" base="$2" attempts=5 i
	for (( i = 1; i <= attempts; i++ )); do
		if git -C "$wt" push origin "HEAD:$base" >/dev/null 2>&1; then
			print_color green "  Pushed '$base' to origin."
			return 0
		fi
		print_color yellow "  Push of '$base' rejected (attempt $i/$attempts) — rebasing the worktree onto the remote and retrying..."
		git -C "$wt" fetch origin "$base" 2>/dev/null || true
		if ! git -C "$wt" rebase "origin/$base" >/dev/null 2>&1; then
			print_color red "  Conflict rebasing '$base' onto the advanced remote during push (left in the worktree)."
			# The rebase is in the worktree, so resolution is off-lock — release it.
			return 2
		fi
	done
	print_color red "  Could not push '$base' after $attempts attempts."
	return 1
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

# Every exit releases the lock via the EXIT trap: all conflicts now surface in
# the WORKTREE (off-lock), so the merge never has to hand a held lock to the
# caller. KEEP_LOCK remains as a defensive guard for the trap, but the normal
# flow leaves it 0.
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

	# Freshen local <base> toward its remote WITHOUT checking it out: fetch, then
	# advance the local ref by the checkout-free primitive when it fast-forwards.
	# (Best effort — tolerate offline; a non-ff local base is left for the rebase
	# onto origin/<base> below to reconcile.)
	git -C "$repo" fetch origin "$base" 2>/dev/null || true
	if git -C "$repo" rev-parse -q --verify "origin/$base" >/dev/null 2>&1; then
		local cur_base remote_base
		cur_base=$(git -C "$repo" rev-parse "$base" 2>/dev/null)
		remote_base=$(git -C "$repo" rev-parse "origin/$base" 2>/dev/null)
		if [[ "$cur_base" != "$remote_base" ]] \
			&& git -C "$repo" merge-base --is-ancestor "$cur_base" "$remote_base" 2>/dev/null; then
			advance_base_ref "$repo" "$base" "$remote_base" "$cur_base" || return 3
		fi
	fi

	# Rebase the feature branch onto the freshened base IN THE WORKTREE, so the
	# integration is linear and any conflict surfaces here — in the worktree,
	# off-lock — rather than in the shared base repo. The base is then advanced by
	# a checkout-free ref update (no merge commit, no working-tree change in the
	# main repo). A dirty worktree cannot be rebased, so refuse it up front. Rebase
	# onto origin/<base> when present (freshest), else the local <base>.
	if [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]; then
		print_color red "  Worktree has uncommitted changes — commit or stash them first: $wt"
		return 3
	fi
	local rebase_onto="$base"
	git -C "$repo" rev-parse -q --verify "origin/$base" >/dev/null 2>&1 && rebase_onto="origin/$base"
	print_color cyan "Rebasing '$branch' onto '$rebase_onto'..."
	if ! git -C "$wt" rebase "$rebase_onto" >/dev/null 2>&1; then
		print_color red "  CONFLICT rebasing '$branch' onto '$rebase_onto'."
		local rf
		while IFS= read -r rf; do
			[[ -n "$rf" ]] && print_color red "    conflict: $rf"
		done < <(git -C "$wt" diff --name-only --diff-filter=U 2>/dev/null)
		print_color yellow "  Rebase left in progress in the worktree: $wt"
		print_color yellow "  Resolve (preserve intent), then continue the rebase:"
		print_color yellow "    git -C '$wt' add -A && git -C '$wt' rebase --continue"
		print_color yellow "  then re-run the merge:"
		print_color yellow "    merge-into-base.sh merge --worktree '$wt'"
		# The conflict lives in the worktree, so resolution happens off-lock and the
		# re-run re-acquires the lock cleanly — do NOT keep the lock.
		return 2
	fi

	# Advance the local <base> ref onto the just-rebased branch tip WITHOUT
	# checking it out. Because the branch now sits directly atop the base tip this
	# is a pure fast-forward of the ref — a linear integration with NO merge commit
	# and no mutation of the main repo's working tree (it is left detached at the
	# old base commit when it had <base> checked out).
	local old_tip new_tip
	old_tip=$(git -C "$repo" rev-parse "$base" 2>/dev/null)
	new_tip=$(git -C "$wt" rev-parse HEAD 2>/dev/null)

	if [[ "$push" == true ]]; then
		# Push the rebased tip straight to origin/<base> FROM THE WORKTREE; a push
		# race is reconciled by a rebase in the worktree (never in the main repo).
		push_with_retry "$wt" "$base"; rc=$?
		if (( rc == 2 )); then
			print_color yellow "  Rebase left in progress in the worktree: $wt (resolve, 'rebase --continue', then re-run merge)"
			return 2
		elif (( rc != 0 )); then
			return 1
		fi
		# The worktree tip may have moved if the push race rebased it; recapture.
		new_tip=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
	fi

	print_color cyan "Advancing '$base' onto '$branch' in $(basename "$repo") (checkout-free)..."
	if advance_base_ref "$repo" "$base" "$new_tip" "$old_tip"; then
		print_color green "  Advanced '$base' onto '$branch' (linear, no merge commit, no checkout)."
		return 0
	fi

	# The ref CAS was refused — the base advanced under us despite the lock (it
	# should not while we hold it). Nothing is left in progress; report a
	# precondition so the caller can retry, which re-rebases onto the new base.
	print_color yellow "  Retry the merge; it will re-rebase '$branch' onto the updated '$base'."
	return 3
}

# Manual escape hatch: push a resolved rebase and release the lock. Run AFTER the
# caller has finished an in-progress rebase (`git rebase --continue`). The normal
# push race no longer strands a rebase in the main repo (it is reconciled in the
# worktree and the lock is released), so this is rarely needed — it exists for a
# lock left held by an interrupted run. Runs in a fresh process, so the lock is
# referenced by path rather than $LOCK_DIR (the exit trap is a no-op here).
do_finalize() {
	local wt="$1" push="$2"
	local repo base rc wt_gitdir
	repo=$(resolve_repo "$wt") || { print_color red "Cannot resolve main repo from worktree: $wt"; return 1; }
	REPO="$repo"
	base=$(find_base_branch "$repo")

	# A push-race rebase now lives in the WORKTREE; refuse until it is finished.
	wt_gitdir=$(git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null)
	if [[ -d "$wt_gitdir/rebase-merge" || -d "$wt_gitdir/rebase-apply" ]]; then
		print_color red "  A rebase is still in progress in the worktree — finish it first: git -C '$wt' rebase --continue"
		return 2
	fi

	if [[ "$push" == true ]]; then
		push_with_retry "$wt" "$base"; rc=$?
		(( rc == 2 )) && return 2
		(( rc != 0 )) && return 1
		# Keep the local <base> ref in step with what we just pushed.
		local old_tip new_tip
		old_tip=$(git -C "$repo" rev-parse "$base" 2>/dev/null)
		new_tip=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
		advance_base_ref "$repo" "$base" "$new_tip" "$old_tip" || true
	fi

	lock_release "$repo/.git/wt-merge.lock"
	print_color green "  Finalized '$base' in $(basename "$repo")."
	return 0
}

# Abort an in-progress rebase/merge and release the lock (escape hatch).
do_abort() {
	local wt="$1" repo
	repo=$(resolve_repo "$wt") || { print_color red "Cannot resolve main repo from worktree: $wt"; return 1; }
	git -C "$wt" rebase --abort 2>/dev/null || true
	git -C "$repo" rebase --abort 2>/dev/null || true
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

# Abort our own in-progress rebase/merge and free the lock when interrupted, so a
# Ctrl-C never leaves the shared repo half-rebased or the lock stuck.
on_signal() {
	KEEP_LOCK=0
	if [[ -n "$LOCK_DIR" ]]; then
		if [[ -n "$REPO" ]]; then
			git -C "$REPO" rebase --abort 2>/dev/null
			git -C "$REPO" merge --abort 2>/dev/null
		fi
		lock_release "$LOCK_DIR"
	fi
	exit 130
}
trap on_signal INT TERM

usage() {
	print_color cyan "Usage: merge-into-base.sh <merge|finalize|abort> --worktree <path> [options]"
	print_color cyan "  merge     Serialize, rebase the branch onto its base IN THE WORKTREE, push it to"
	print_color cyan "            origin/<base>, then advance the local base ref checkout-free (no merge commit)."
	print_color cyan "  finalize  Escape hatch: push a resolved rebase and release a stuck lock."
	print_color cyan "  abort     Abort an in-progress rebase/merge and release the lock."
	print_color cyan "Options:"
	print_color cyan "  --worktree <path>  The wcreated worktree whose branch to merge (required)."
	print_color cyan "  --timeout <sec>    Max seconds to wait for the lock (default $WT_MERGE_TIMEOUT)."
	print_color cyan "  --poll <sec>       Poll interval while waiting (default $WT_MERGE_POLL)."
	print_color cyan "  --stale <sec>      Reclaim a lock older than this (default $WT_MERGE_STALE)."
	print_color cyan "  --no-push          Integrate locally without pushing."
	print_color cyan "Exit: 0 ok | 2 conflict (rebase left in the worktree, lock freed — resolve, 'rebase --continue', re-run merge) | 3 precondition | 4 lock timeout | 1 error"
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
