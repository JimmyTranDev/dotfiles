#!/usr/bin/env zsh
# Tests for merge-into-base.sh: checkout-free rebase-then-advance behavior
# (/implement-worktree Phase 7). Black-box — each test builds a throwaway
# origin + main repo + feature worktree in a temp dir and drives the helper as a
# subprocess.
#
# Run: zsh etc/scripts/tests/test_merge_into_base.zsh
#
# Pins the behavior behind the "rebase onto base, resolve, merge & clean up"
# option. Integration happens ENTIRELY in the worktree: the branch is rebased in
# the worktree, its tip is pushed straight to origin/<base>, and the LOCAL <base>
# ref is advanced by a checkout-free `update-ref` (with a detach-guard when base
# is checked out). The main repo's working tree is NEVER checked out onto <base>
# and is never mutated. Concretely:
#   1. clean    — the feature branch is rebased onto an advanced base, then the
#                 base *ref* is fast-forwarded onto it (linear, NO merge commit —
#                 base ref ends identical to the branch tip). The main repo is
#                 left DETACHED at the old base commit with a CLEAN working tree
#                 (base was never checked out), and the feature file is NOT in the
#                 main repo's working tree even though it IS in the base ref.
#   2. conflict — a rebase conflict is left IN THE WORKTREE with the lock
#                 RELEASED; after the caller resolves + `rebase --continue`, a
#                 re-run advances the base ref cleanly.
#   3. dirty    — a worktree with uncommitted changes is refused (exit 3) before
#                 any rebase/ref move happens.
#   4. push race — a non-fast-forward push is integrated by rebasing IN THE
#                 WORKTREE onto the advanced remote and re-pushing (linear, no
#                 merge commit); the main repo is never left mid-rebase/merge.

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}"        # etc/scripts/tests/<file> -> repo root
HELPER="$REPO_ROOT/etc/scripts/src/worktrees/merge-into-base.sh"

typeset -i PASS=0 FAIL=0
typeset -a TMPDIRS

pass() { print -r -- "  ok: $1"; (( PASS++ )); }
fail() {
  print -r -- "FAIL: $1"
  [[ -n "${2:-}" ]] && print -r -- "    $2"
  (( FAIL++ ))
}
assert_eq() {
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "expected [$2], got [$3]"; fi
}

cleanup() { local d; for d in "${TMPDIRS[@]}"; do rm -rf "$d"; done }
trap cleanup EXIT

exists()     { [[ -e "$1" ]] && print -r -- yes || print -r -- no }
dir_exists() { [[ -d "$1" ]] && print -r -- yes || print -r -- no }

# Is <target> present in <repo>'s <ref> tree? (ref content, not the working
# tree.) NB: the local is `p`, never `path` — `path` is a zsh special array tied
# to $PATH, so a `local path=...` would break `git` lookups inside the function.
in_ref_tree() {
  local repo="$1" ref="$2" p="$3"
  [[ -n "$(git -C "$repo" ls-tree --name-only "$ref" -- "$p" 2>/dev/null)" ]] \
    && print -r -- yes || print -r -- no
}

# Is <repo>'s HEAD detached? (i.e. base was NOT left checked out.)
is_detached() {
  git -C "$1" symbolic-ref -q HEAD >/dev/null 2>&1 && print -r -- no || print -r -- yes
}

# Configure a throwaway repo: identity, no signing, no global hooks.
configure_repo() {
  local r="$1"
  git -C "$r" config user.email "test@example.com"
  git -C "$r" config user.name  "Test"
  git -C "$r" config commit.gpgsign false
  git -C "$r" config core.hooksPath "$NOHOOKS"
}

# Drive the helper's `merge` non-interactively; echo nothing, return its code.
run_merge() {
  local wt="$1"
  zsh "$HELPER" merge --worktree "$wt" --no-push \
    --timeout 30 --poll 1 --stale 3 >/dev/null 2>&1
  return $?
}

# Drive `merge` WITH push (no --no-push), so push_with_retry runs; return its code.
run_merge_push() {
  local wt="$1"
  zsh "$HELPER" merge --worktree "$wt" \
    --timeout 30 --poll 1 --stale 3 >/dev/null 2>&1
  return $?
}

# ---------------------------------------------------------------------------
# Test 1: clean rebase-then-advance onto an advanced base, checkout-free.
# ---------------------------------------------------------------------------
test_clean() {
  local TMP; TMP=$(mktemp -d "${TMPDIR:-/tmp}/mib.XXXXXX"); TMPDIRS+=("$TMP")
  local NOHOOKS="$TMP/nohooks"; mkdir -p "$NOHOOKS"
  local ORIGIN="$TMP/origin.git" MAIN="$TMP/main" WT="$TMP/wt" ADV="$TMP/adv"

  git init --bare -b main "$ORIGIN" >/dev/null 2>&1

  git init -b main "$MAIN" >/dev/null 2>&1
  configure_repo "$MAIN"
  git -C "$MAIN" remote add origin "$ORIGIN"
  print -r -- base > "$MAIN/README.md"
  git -C "$MAIN" add -A && git -C "$MAIN" commit -m C0 >/dev/null 2>&1
  git -C "$MAIN" push -u origin main >/dev/null 2>&1

  git -C "$MAIN" worktree add -b feat "$WT" main >/dev/null 2>&1
  print -r -- hi > "$WT/feature.txt"
  git -C "$WT" add -A && git -C "$WT" commit -m C1 >/dev/null 2>&1

  git clone "$ORIGIN" "$ADV" >/dev/null 2>&1
  configure_repo "$ADV"
  print -r -- other > "$ADV/other.txt"
  git -C "$ADV" add -A && git -C "$ADV" commit -m C2 >/dev/null 2>&1
  git -C "$ADV" push origin main >/dev/null 2>&1
  local adv_sha; adv_sha=$(git -C "$ADV" rev-parse HEAD)

  run_merge "$WT"; local rc=$?

  assert_eq "clean: helper exits 0" 0 "$rc"

  # The base REF advanced (its tree carries the feature + the advanced-base file),
  # even though the main repo's WORKING TREE was never checked out onto base.
  assert_eq "clean: feature.txt is in the base ref tree" yes "$(in_ref_tree "$MAIN" main feature.txt)"
  assert_eq "clean: advanced base commit (other.txt) is in the base ref tree" yes "$(in_ref_tree "$MAIN" main other.txt)"

  local anc=no
  git -C "$MAIN" merge-base --is-ancestor "$adv_sha" feat 2>/dev/null && anc=yes
  assert_eq "clean: base advance is an ancestor of feat (rebased, not just merged)" yes "$anc"

  # Fully linear: the base ref is fast-forwarded onto the rebased branch, so its
  # tip is IDENTICAL to the branch tip — no merge commit was created.
  assert_eq "clean: base ref fast-forwarded to feat tip (no merge commit)" \
    "$(git -C "$MAIN" rev-parse feat)" "$(git -C "$MAIN" rev-parse main)"

  # Checkout-free: base was NOT left checked out — the main repo is detached at
  # the OLD base commit, and its working tree is clean and does NOT hold the new
  # feature file (proving integration never touched the main repo's working tree).
  assert_eq "clean: base was never checked out (main repo detached)" yes "$(is_detached "$MAIN")"
  assert_eq "clean: main repo working tree stayed clean" "" "$(git -C "$MAIN" status --porcelain 2>/dev/null)"
  assert_eq "clean: feature.txt NOT in the main repo working tree" no "$(exists "$MAIN/feature.txt")"

  assert_eq "clean: merge lock released" no "$(dir_exists "$MAIN/.git/wt-merge.lock")"
}

# ---------------------------------------------------------------------------
# Test 2: a rebase conflict is left in the worktree with the lock RELEASED;
#         a resolve + re-run then advances the base cleanly.
# ---------------------------------------------------------------------------
test_conflict_then_recover() {
  local TMP; TMP=$(mktemp -d "${TMPDIR:-/tmp}/mib.XXXXXX"); TMPDIRS+=("$TMP")
  local NOHOOKS="$TMP/nohooks"; mkdir -p "$NOHOOKS"
  local ORIGIN="$TMP/origin.git" MAIN="$TMP/main" WT="$TMP/wt" ADV="$TMP/adv"

  git init --bare -b main "$ORIGIN" >/dev/null 2>&1

  git init -b main "$MAIN" >/dev/null 2>&1
  configure_repo "$MAIN"
  git -C "$MAIN" remote add origin "$ORIGIN"
  print -r -- base > "$MAIN/file.txt"
  git -C "$MAIN" add -A && git -C "$MAIN" commit -m C0 >/dev/null 2>&1
  git -C "$MAIN" push -u origin main >/dev/null 2>&1

  git -C "$MAIN" worktree add -b feat "$WT" main >/dev/null 2>&1
  print -r -- feat > "$WT/file.txt"
  git -C "$WT" add -A && git -C "$WT" commit -m C1 >/dev/null 2>&1

  git clone "$ORIGIN" "$ADV" >/dev/null 2>&1
  configure_repo "$ADV"
  print -r -- main > "$ADV/file.txt"
  git -C "$ADV" add -A && git -C "$ADV" commit -m C2 >/dev/null 2>&1
  git -C "$ADV" push origin main >/dev/null 2>&1

  run_merge "$WT"; local rc=$?

  assert_eq "conflict: helper exits 2" 2 "$rc"
  assert_eq "conflict: lock RELEASED (resolution happens off-lock)" no \
    "$(dir_exists "$MAIN/.git/wt-merge.lock")"

  local wt_gitdir; wt_gitdir=$(git -C "$WT" rev-parse --absolute-git-dir 2>/dev/null)
  assert_eq "conflict: rebase left in progress in the worktree" yes \
    "$(dir_exists "$wt_gitdir/rebase-merge")"

  local mh=yes
  git -C "$MAIN" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 || mh=no
  assert_eq "conflict: base repo is NOT left mid-merge" no "$mh"

  # Recovery is only meaningful once the rebase is actually in the worktree.
  if [[ -d "$wt_gitdir/rebase-merge" ]]; then
    print -r -- resolved > "$WT/file.txt"
    git -C "$WT" add file.txt
    GIT_EDITOR=true git -C "$WT" rebase --continue >/dev/null 2>&1

    run_merge "$WT"; local rc2=$?
    assert_eq "recover: re-run merge exits 0" 0 "$rc2"
    # Assert against the base REF's tree content, not the main repo working tree.
    assert_eq "recover: resolved content landed on the base ref" resolved \
      "$(git -C "$MAIN" show main:file.txt 2>/dev/null)"
    assert_eq "recover: base was never checked out (main repo detached)" yes "$(is_detached "$MAIN")"
    assert_eq "recover: merge lock released" no "$(dir_exists "$MAIN/.git/wt-merge.lock")"
  else
    fail "recover: expected a worktree rebase to resolve (skipped recovery)"
  fi
}

# ---------------------------------------------------------------------------
# Test 3: a dirty worktree is refused before any rebase/ref move.
# ---------------------------------------------------------------------------
test_dirty_worktree() {
  local TMP; TMP=$(mktemp -d "${TMPDIR:-/tmp}/mib.XXXXXX"); TMPDIRS+=("$TMP")
  local NOHOOKS="$TMP/nohooks"; mkdir -p "$NOHOOKS"
  local ORIGIN="$TMP/origin.git" MAIN="$TMP/main" WT="$TMP/wt"

  git init --bare -b main "$ORIGIN" >/dev/null 2>&1

  git init -b main "$MAIN" >/dev/null 2>&1
  configure_repo "$MAIN"
  git -C "$MAIN" remote add origin "$ORIGIN"
  print -r -- base > "$MAIN/README.md"
  git -C "$MAIN" add -A && git -C "$MAIN" commit -m C0 >/dev/null 2>&1
  git -C "$MAIN" push -u origin main >/dev/null 2>&1

  git -C "$MAIN" worktree add -b feat "$WT" main >/dev/null 2>&1
  print -r -- hi > "$WT/feature.txt"
  git -C "$WT" add -A && git -C "$WT" commit -m C1 >/dev/null 2>&1
  # Make the worktree dirty (uncommitted change to a tracked file).
  print -r -- dirty >> "$WT/feature.txt"

  run_merge "$WT"; local rc=$?
  assert_eq "dirty: helper exits 3 (precondition)" 3 "$rc"
  # The base ref must NOT have advanced (nothing was integrated).
  assert_eq "dirty: base ref does not carry feature.txt" no "$(in_ref_tree "$MAIN" main feature.txt)"
  assert_eq "dirty: merge lock released" no "$(dir_exists "$MAIN/.git/wt-merge.lock")"
}

# ---------------------------------------------------------------------------
# Test 4: a push race is integrated by REBASING the branch onto the advanced
#         remote IN THE WORKTREE (not a merge commit), keeping history linear.
#
# A one-shot pre-push hook advances origin/main with a NON-conflicting commit
# right as the helper pushes, so the first push is rejected as non-fast-forward.
# push_with_retry must then fetch + `rebase origin/main` IN THE WORKTREE and
# re-push, landing a LINEAR base whose tip has BOTH the remote's race commit and
# our feature commit as ancestors, with NO merge commit, without ever leaving the
# main repo mid-rebase/merge.
# ---------------------------------------------------------------------------
test_push_race_rebase() {
  local TMP; TMP=$(mktemp -d "${TMPDIR:-/tmp}/mib.XXXXXX"); TMPDIRS+=("$TMP")
  local NOHOOKS="$TMP/nohooks"; mkdir -p "$NOHOOKS"
  local ORIGIN="$TMP/origin.git" MAIN="$TMP/main" WT="$TMP/wt" SIDE="$TMP/side"
  local HOOKS="$TMP/hooks"; mkdir -p "$HOOKS"

  git init --bare -b main "$ORIGIN" >/dev/null 2>&1

  git init -b main "$MAIN" >/dev/null 2>&1
  configure_repo "$MAIN"
  git -C "$MAIN" remote add origin "$ORIGIN"
  print -r -- base > "$MAIN/README.md"
  git -C "$MAIN" add -A && git -C "$MAIN" commit -m C0 >/dev/null 2>&1
  git -C "$MAIN" push -u origin main >/dev/null 2>&1

  git -C "$MAIN" worktree add -b feat "$WT" main >/dev/null 2>&1
  print -r -- hi > "$WT/feature.txt"
  git -C "$WT" add -A && git -C "$WT" commit -m C1 >/dev/null 2>&1

  # Build a racing commit in a side clone and TRANSFER ITS OBJECTS into origin
  # ahead of time under a hidden ref (objects present, but origin/main still at
  # C0). The one-shot pre-push hook then advances origin/main to that commit via
  # a DIRECT bare-repo `update-ref` — no nested client `git push`, which would
  # deadlock against the outer push holding the local bare repo's receive lock.
  git clone "$ORIGIN" "$SIDE" >/dev/null 2>&1
  configure_repo "$SIDE"
  print -r -- race > "$SIDE/race.txt"
  git -C "$SIDE" add -A && git -C "$SIDE" commit -m RACE >/dev/null 2>&1
  local race_sha; race_sha=$(git -C "$SIDE" rev-parse HEAD 2>/dev/null)
  local hidden="${race_sha}:refs/hidden/race"
  git -C "$SIDE" push origin "$hidden" >/dev/null 2>&1

  # One-shot pre-push hook (installed on the WORKTREE — where the push now runs):
  # consume the ref list on stdin, advance origin/main to the pre-transferred
  # race commit so the outer push is rejected as non-fast-forward, then delete
  # itself so the helper's retry (rebase-in-worktree + re-push) lands cleanly.
  cat > "$HOOKS/pre-push" <<HOOK
#!/bin/sh
cat >/dev/null
git --git-dir="$ORIGIN" update-ref refs/heads/main "$race_sha"
rm -f "$HOOKS/pre-push"
exit 0
HOOK
  chmod +x "$HOOKS/pre-push"
  git -C "$WT" config core.hooksPath "$HOOKS"

  run_merge_push "$WT"; local rc=$?

  # Restore the no-hooks path so cleanup/other ops aren't affected.
  git -C "$WT" config core.hooksPath "$NOHOOKS"

  assert_eq "push-race: helper exits 0" 0 "$rc"

  # Everything landed on the remote: our feature file and the racing file.
  local origin_main; origin_main=$(git -C "$MAIN" ls-remote origin main 2>/dev/null | awk '{print $1}')
  local feat_on_remote=no race_on_remote=no
  [[ -n "$(git -C "$MAIN" ls-tree --name-only "$origin_main" -- feature.txt 2>/dev/null)" ]] && feat_on_remote=yes
  [[ -n "$(git -C "$MAIN" ls-tree --name-only "$origin_main" -- race.txt 2>/dev/null)" ]] && race_on_remote=yes
  assert_eq "push-race: feature.txt pushed to origin" yes "$feat_on_remote"
  assert_eq "push-race: racing commit's file present on origin" yes "$race_on_remote"

  # Linear: no merge commit on the base tip (a fast-forward/rebase result has a
  # single parent), and the race commit is an ancestor of the final tip.
  git -C "$MAIN" fetch origin main >/dev/null 2>&1
  local nparents; nparents=$(git -C "$MAIN" rev-list --parents -n1 "$origin_main" 2>/dev/null | awk '{print NF-1}')
  assert_eq "push-race: base tip has ONE parent (no merge commit)" 1 "$nparents"

  local anc=no
  git -C "$MAIN" merge-base --is-ancestor "$race_sha" "$origin_main" 2>/dev/null && anc=yes
  assert_eq "push-race: remote race commit is an ancestor of the pushed base" yes "$anc"

  # The race is resolved by a rebase IN THE WORKTREE — the main repo is never
  # left mid-rebase or mid-merge.
  local main_gitdir; main_gitdir=$(git -C "$MAIN" rev-parse --absolute-git-dir 2>/dev/null)
  assert_eq "push-race: main repo NOT left mid-rebase" no "$(dir_exists "$main_gitdir/rebase-merge")"
  local mh=yes
  git -C "$MAIN" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 || mh=no
  assert_eq "push-race: main repo NOT left mid-merge" no "$mh"

  assert_eq "push-race: merge lock released" no "$(dir_exists "$MAIN/.git/wt-merge.lock")"
}

test_clean
test_conflict_then_recover
test_dirty_worktree
test_push_race_rebase

print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
