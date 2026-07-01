#!/usr/bin/env zsh
# Tests for the pure helpers behind `worktree delete` (commands/delete.sh):
#
#   worktree_delete_label        the fzf picker label for one worktree:
#                                "[<repo>] <parent-folder>/<name>"
#   collect_worktrees_from_dirs  enumerate worktrees under the created/checkout
#                                containers, ordered by last change (mtime),
#                                newest first
#
# Run: zsh etc/scripts/tests/test_worktree_delete.zsh
#
# The interactive fzf multi-select and the git-mutating delete loop in
# cmd_delete are not unit-tested here; this pins the deterministic label
# formatting (which now surfaces the parent folder) and the recency ordering.

emulate -L zsh
set -u

# Isolate every git call (fixtures + code under test) from the user's global
# hooks/config (e.g. the repo's gitleaks pre-commit), so the suite is hermetic.
git() { command git -c core.hooksPath=/dev/null "$@"; }

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/utility.sh"                    # get_worktree_project_name
source "$REPO_ROOT/etc/scripts/src/worktrees/commands/delete.sh"    # helpers under test

typeset -i PASS=0 FAIL=0

pass() { print -r -- "  ok: $1"; (( PASS++ )); }
fail() {
  print -r -- "FAIL: $1"
  (( FAIL++ ))
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc"
    print -r -- "    expected: [$expected]"
    print -r -- "    actual:   [$actual]"
  fi
}

# --- Fixture -----------------------------------------------------------------
FIX="$(mktemp -d "${TMPDIR:-/tmp}/wtdelete.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# --- Part A: worktree_delete_label shows "[repo] parent/name" ----------------
# Containers are named wcreated/wcheckout so the parent-folder segment of the
# label is asserted verbatim. Fake .git gitdir pointers resolve the repo name.
CREATED="$FIX/wcreated"
CHECKOUT="$FIX/wcheckout"
mkdir -p "$CREATED/alpha" "$CHECKOUT/beta" "$CREATED/plain"
print -r -- "gitdir: /elsewhere/orgA/repo1/.git/worktrees/alpha" > "$CREATED/alpha/.git"
print -r -- "gitdir: /elsewhere/orgB/repo2/.git/worktrees/beta" > "$CHECKOUT/beta/.git"

assert_eq "label shows parent folder + repo + name (created worktree)" \
  "[repo1] wcreated/alpha" "$(worktree_delete_label "$CREATED/alpha")"
assert_eq "label shows parent folder + repo + name (checkout worktree)" \
  "[repo2] wcheckout/beta" "$(worktree_delete_label "$CHECKOUT/beta")"
assert_eq "label falls back to [unknown] when repo is unresolvable, still shows parent" \
  "[unknown] wcreated/plain" "$(worktree_delete_label "$CREATED/plain")"
# A trailing slash on the path must not change the label.
assert_eq "label is stable with a trailing slash on the path" \
  "[repo1] wcreated/alpha" "$(worktree_delete_label "$CREATED/alpha/")"

# --- Part B: collect_worktrees_from_dirs orders by last change (mtime) --------
# macOS/APFS keeps a file's birth time at creation, and `touch -t` to a PAST date
# drags birth back to match mtime -- so past stamps cannot tell `stat -f %B`
# (birth) apart from `%m` (mtime). Touching to FUTURE dates instead leaves birth
# at creation while moving mtime forward, so the two keys diverge. The dirs are
# CREATED in the OPPOSITE order to their mtimes (each >=1s apart via sleep), so a
# birth-time sort (the old macOS behaviour) yields oldest,middle,newest while a
# last-change (mtime) sort must yield newest,middle,oldest -- pinning the fix,
# not the platform.
SCREATED="$FIX/sort/wcreated"
SCHECKOUT="$FIX/sort/wcheckout"
mkdir -p "$SCREATED" "$SCHECKOUT"
mkdir "$SCREATED/newest"  && touch -t 203001010000 "$SCREATED/newest";  sleep 1.1
mkdir "$SCHECKOUT/middle" && touch -t 202901010000 "$SCHECKOUT/middle"; sleep 1.1
mkdir "$SCREATED/oldest"  && touch -t 202801010000 "$SCREATED/oldest"

# Point the env at the fixtures too, so the ordering is asserted against the
# fixtures whether the function reads args or the WCREATED_DIR/WCHECKOUT_DIR env.
export WCREATED_DIR="$SCREATED" WCHECKOUT_DIR="$SCHECKOUT"

expected_order="$SCREATED/newest
$SCHECKOUT/middle
$SCREATED/oldest"
assert_eq "worktrees are listed newest-change first (across both containers)" \
  "$expected_order" "$(collect_worktrees_from_dirs "$SCREATED" "$SCHECKOUT")"

# A missing container is skipped silently (only the created side remains).
miss="$(collect_worktrees_from_dirs "$SCREATED" "$FIX/does-not-exist" 2>/dev/null)"
assert_eq "missing checkout container is skipped without error" \
  "$SCREATED/newest
$SCREATED/oldest" "$miss"

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
