#!/usr/bin/env zsh
# Tests for _worktree_list_entries — the pure, deterministic core of
# `worktree list`. It scans the wcreated/wcheckout containers and emits one
# tab-separated row per worktree:
#
#   category \t name \t repo \t branch \t dirty \t ahead \t behind \t path
#
# Run: zsh etc/scripts/tests/test_worktree_list.zsh
#
# The colored table rendering in cmd_list is presentational and not unit-tested
# here; this pins the discovery, categorization, repo resolution, and the
# branch / dirty / ahead-behind status derivation.

emulate -L zsh
set -u

# Isolate every git call in this test (fixture setup *and* the code under test)
# from the user's global hooks and config (e.g. the repo's gitleaks pre-commit),
# so the suite is hermetic and quiet regardless of the host environment.
git() { command git -c core.hooksPath=/dev/null "$@"; }

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/utility.sh"                   # get_worktree_project_name
source "$REPO_ROOT/etc/scripts/src/worktrees/commands/list.sh"     # _worktree_list_entries

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

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$desc"
  else
    fail "$desc"
    print -r -- "    missing: [$needle]"
  fi
}

# Pull one field (1-based column) from the row whose name (col 2) matches $2.
field_for() {
  local entries="$1" name="$2" col="$3"
  print -r -- "$entries" | awk -F'\t' -v n="$name" -v c="$col" '$2==n {print $c}'
}

nonempty_lines() { print -r -- "$1" | grep -c .; }

# --- Fixture -----------------------------------------------------------------
FIX="$(mktemp -d "${TMPDIR:-/tmp}/wtlist.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

CREATED="$FIX/wcreated"
CHECKOUT="$FIX/wcheckout"
mkdir -p "$CREATED" "$CHECKOUT"

# --- Part A: pure discovery with fake .git pointer files ---------------------
# Two valid worktrees (one per container) plus two decoys that must be skipped.
mkdir -p "$CREATED/alpha" "$CHECKOUT/beta"
print -r -- "gitdir: /elsewhere/orgA/repo1/.git/worktrees/alpha" > "$CREATED/alpha/.git"
print -r -- "gitdir: /elsewhere/orgB/repo2/.git/worktrees/beta" > "$CHECKOUT/beta/.git"

mkdir -p "$CREATED/plain"                                   # no .git at all
mkdir -p "$CREATED/bogus"
print -r -- "this is not a gitdir pointer" > "$CREATED/bogus/.git"

entriesA="$(_worktree_list_entries "$CREATED" "$CHECKOUT")"

assert_eq "lists exactly 2 worktrees (skips plain dir + bogus .git)" \
  "2" "$(nonempty_lines "$entriesA")"
assert_eq "alpha is categorized as created (from wcreated container)" \
  "created" "$(field_for "$entriesA" alpha 1)"
assert_eq "beta is categorized as checkout (from wcheckout container)" \
  "checkout" "$(field_for "$entriesA" beta 1)"
assert_eq "alpha repo resolved from its gitdir pointer" \
  "repo1" "$(field_for "$entriesA" alpha 3)"
assert_eq "beta repo resolved from its gitdir pointer" \
  "repo2" "$(field_for "$entriesA" beta 3)"
assert_contains "alpha row carries its absolute path" \
  "$entriesA" "$CREATED/alpha"
assert_eq "alpha has no resolvable branch yet (dangling gitdir) -> '-'" \
  "-" "$(field_for "$entriesA" alpha 4)"

# A missing container dir is skipped silently (only created side remains).
miss="$(_worktree_list_entries "$CREATED" "$FIX/does-not-exist" 2>/dev/null)"
assert_eq "missing checkout container is skipped without error (1 remains)" \
  "1" "$(nonempty_lines "$miss")"

# Both containers empty/missing -> no rows, no error.
empty="$(_worktree_list_entries "$FIX/nope1" "$FIX/nope2" 2>/dev/null)"
assert_eq "no containers -> zero rows" "0" "$(nonempty_lines "$empty")"

# --- Part B: real git for branch / dirty / ahead-behind ----------------------
if ! command -v git >/dev/null 2>&1; then
  print -r -- "  skip: git not available, skipping status assertions"
else
  REMOTE="$FIX/remote.git"
  MAIN="$FIX/realmain"
  git init -q --bare "$REMOTE"
  git init -q -b main "$MAIN"
  git -C "$MAIN" config user.email "t@example.com"
  git -C "$MAIN" config user.name "Test"
  print -r -- "hello" > "$MAIN/file.txt"
  git -C "$MAIN" add -A
  git -C "$MAIN" commit -qm "init"
  git -C "$MAIN" remote add origin "$REMOTE"
  git -C "$MAIN" push -q -u origin main

  # A created-style worktree on a fresh local branch (no upstream).
  git -C "$MAIN" worktree add -q -b feature/x "$CREATED/feature-x" >/dev/null 2>&1

  entriesB="$(_worktree_list_entries "$CREATED" "$CHECKOUT")"
  assert_eq "feature-x reports its checked-out branch" \
    "feature/x" "$(field_for "$entriesB" feature-x 4)"
  assert_eq "feature-x repo resolves to the main repo basename" \
    "realmain" "$(field_for "$entriesB" feature-x 3)"
  assert_eq "clean feature-x worktree has dirty=0" \
    "0" "$(field_for "$entriesB" feature-x 5)"

  # Make it dirty.
  print -r -- "local change" >> "$CREATED/feature-x/file.txt"
  entriesB="$(_worktree_list_entries "$CREATED" "$CHECKOUT")"
  assert_eq "modified feature-x worktree has dirty=1" \
    "1" "$(field_for "$entriesB" feature-x 5)"

  # An untracked file alone also counts as dirty.
  git -C "$MAIN" worktree add -q -b feature/y "$CREATED/feature-y" >/dev/null 2>&1
  print -r -- "junk" > "$CREATED/feature-y/untracked.txt"
  entriesB="$(_worktree_list_entries "$CREATED" "$CHECKOUT")"
  assert_eq "untracked-only feature-y worktree has dirty=1" \
    "1" "$(field_for "$entriesB" feature-y 5)"

  # A checkout-style worktree tracking origin/main, then one commit ahead.
  git -C "$MAIN" worktree add -q --track -b trackmain "$CHECKOUT/track" origin/main >/dev/null 2>&1
  entriesB="$(_worktree_list_entries "$CREATED" "$CHECKOUT")"
  assert_eq "freshly tracked worktree is ahead=0" \
    "0" "$(field_for "$entriesB" track 6)"
  assert_eq "freshly tracked worktree is behind=0" \
    "0" "$(field_for "$entriesB" track 7)"

  print -r -- "more" >> "$CHECKOUT/track/file.txt"
  git -C "$CHECKOUT/track" add -A
  git -C "$CHECKOUT/track" commit -qm "ahead by one"
  entriesB="$(_worktree_list_entries "$CREATED" "$CHECKOUT")"
  assert_eq "local commit makes tracked worktree ahead=1" \
    "1" "$(field_for "$entriesB" track 6)"
  assert_eq "tracked worktree stays behind=0 (left/right not swapped)" \
    "0" "$(field_for "$entriesB" track 7)"
fi

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
