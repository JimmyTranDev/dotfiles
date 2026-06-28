#!/usr/bin/env zsh
# Tests for merge-into-base.sh: rebase-then-merge behavior (/implement-worktree
# Phase 7). Black-box — each test builds a throwaway origin + main repo + feature
# worktree in a temp dir and drives the helper as a subprocess.
#
# Run: zsh etc/scripts/tests/test_merge_into_base.zsh
#
# Pins the behavior behind the "rebase onto base, resolve, merge & clean up"
# option:
#   1. clean    — the feature branch is rebased onto an advanced base BEFORE the
#                 merge (so the advance becomes an ancestor of the branch), then
#                 merged.
#   2. conflict — a rebase conflict is left IN THE WORKTREE with the lock
#                 RELEASED; after the caller resolves + `rebase --continue`, a
#                 re-run merges cleanly.
#   3. dirty    — a worktree with uncommitted changes is refused (exit 3) before
#                 any rebase/merge happens.

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

# ---------------------------------------------------------------------------
# Test 1: clean rebase-then-merge onto an advanced base
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
  assert_eq "clean: feature.txt landed on base" yes "$(exists "$MAIN/feature.txt")"
  assert_eq "clean: advanced base commit (other.txt) present" yes "$(exists "$MAIN/other.txt")"

  local anc=no
  git -C "$MAIN" merge-base --is-ancestor "$adv_sha" feat 2>/dev/null && anc=yes
  assert_eq "clean: base advance is an ancestor of feat (rebased, not just merged)" yes "$anc"

  assert_eq "clean: merge lock released" no "$(dir_exists "$MAIN/.git/wt-merge.lock")"
}

# ---------------------------------------------------------------------------
# Test 2: a rebase conflict is left in the worktree with the lock RELEASED;
#         a resolve + re-run then merges cleanly.
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
    assert_eq "recover: resolved content landed on base" resolved "$(< "$MAIN/file.txt")"
    assert_eq "recover: merge lock released" no "$(dir_exists "$MAIN/.git/wt-merge.lock")"
  else
    fail "recover: expected a worktree rebase to resolve (skipped recovery)"
  fi
}

# ---------------------------------------------------------------------------
# Test 3: a dirty worktree is refused before any rebase/merge.
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
  assert_eq "dirty: nothing merged into base" no "$(exists "$MAIN/feature.txt")"
  assert_eq "dirty: merge lock released" no "$(dir_exists "$MAIN/.git/wt-merge.lock")"
}

test_clean
test_conflict_then_recover
test_dirty_worktree

print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
