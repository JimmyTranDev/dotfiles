#!/usr/bin/env zsh
# Tests for the pure helpers behind `worktree diff` (commands/diff.sh):
#
#   _worktree_diff_range        compute the git diff range for single/pair mode
#   _worktree_diff_main_repo    parse a worktree's main repo from its .git pointer
#   _worktree_diff_same_repo    decide whether two worktrees share a repo
#   _worktree_diff_resolve_name resolve a name/path to a worktree directory
#
# Run: zsh etc/scripts/tests/test_worktree_diff.zsh
#
# The interactive bits (fzf picking) and the thin git-invoking runners
# (_worktree_diff_single / _worktree_diff_pair) are not unit-tested here; this
# pins the deterministic core that decides *what* gets diffed.

emulate -L zsh
set -u

# Isolate every git call (fixtures + code under test) from the user's global
# hooks/config (e.g. the repo's gitleaks pre-commit), so the suite is hermetic.
git() { command git -c core.hooksPath=/dev/null "$@"; }

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/src/worktrees/commands/diff.sh" # pure helpers

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

# Assert a command succeeds (exit 0).
assert_ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc (expected success, got exit $?)"
  fi
}

# Assert a command fails (non-zero exit).
assert_fail() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    fail "$desc (expected failure, got success)"
  else
    pass "$desc"
  fi
}

# --- Part A: _worktree_diff_range (pure string) ------------------------------
assert_eq "single mode -> <base>...HEAD (develop)" \
  "develop...HEAD" "$(_worktree_diff_range single develop)"
assert_eq "single mode -> <base>...HEAD (main)" \
  "main...HEAD" "$(_worktree_diff_range single main)"
assert_eq "pair mode -> <branchA>...<branchB>" \
  "feature/a...feature/b" "$(_worktree_diff_range pair feature/a feature/b)"
assert_fail "single mode with empty base fails" _worktree_diff_range single ""
assert_fail "pair mode with a missing branch fails" _worktree_diff_range pair a ""
assert_fail "unknown mode fails" _worktree_diff_range bogus x y

# --- Fixtures for the filesystem helpers -------------------------------------
FIX="$(mktemp -d "${TMPDIR:-/tmp}/wtdiff.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

CREATED="$FIX/wcreated"
CHECKOUT="$FIX/wcheckout"
mkdir -p "$CREATED" "$CHECKOUT"

# Fake worktree pointer files: alpha & gamma share repo1; beta is in repo2.
mkdir -p "$CREATED/alpha" "$CREATED/gamma" "$CHECKOUT/beta"
print -r -- "gitdir: /elsewhere/orgA/repo1/.git/worktrees/alpha" > "$CREATED/alpha/.git"
print -r -- "gitdir: /elsewhere/orgA/repo1/.git/worktrees/gamma" > "$CREATED/gamma/.git"
print -r -- "gitdir: /elsewhere/orgB/repo2/.git/worktrees/beta"  > "$CHECKOUT/beta/.git"

# Decoys that must never resolve.
mkdir -p "$CREATED/plain"                                  # no .git at all
mkdir -p "$CREATED/bogus"
print -r -- "this is not a gitdir pointer" > "$CREATED/bogus/.git"

# --- Part B: _worktree_diff_main_repo (pure .git parse) ----------------------
assert_eq "main repo parsed from a worktree pointer" \
  "/elsewhere/orgA/repo1" "$(_worktree_diff_main_repo "$CREATED/alpha")"
assert_fail "main repo fails on a dir with no .git" _worktree_diff_main_repo "$CREATED/plain"
assert_fail "main repo fails on a bogus .git pointer" _worktree_diff_main_repo "$CREATED/bogus"

# --- Part C: _worktree_diff_same_repo ----------------------------------------
assert_eq "same-repo worktrees -> shared repo path" \
  "/elsewhere/orgA/repo1" "$(_worktree_diff_same_repo "$CREATED/alpha" "$CREATED/gamma")"
assert_ok "same-repo worktrees return success" \
  _worktree_diff_same_repo "$CREATED/alpha" "$CREATED/gamma"
assert_fail "different-repo worktrees return failure" \
  _worktree_diff_same_repo "$CREATED/alpha" "$CHECKOUT/beta"
assert_fail "unresolvable worktree makes same-repo fail" \
  _worktree_diff_same_repo "$CREATED/alpha" "$CREATED/plain"

# --- Part D: _worktree_diff_resolve_name -------------------------------------
exp_alpha="$CREATED/alpha"; exp_alpha="${exp_alpha:A}"
exp_beta="$CHECKOUT/beta";  exp_beta="${exp_beta:A}"

assert_eq "resolve a name found under the created container" \
  "$exp_alpha" "$(_worktree_diff_resolve_name alpha "$CREATED" "$CHECKOUT")"
assert_eq "resolve a name found under the checkout container" \
  "$exp_beta" "$(_worktree_diff_resolve_name beta "$CREATED" "$CHECKOUT")"
assert_eq "resolve a direct worktree path" \
  "$exp_alpha" "$(_worktree_diff_resolve_name "$CREATED/alpha" "$CREATED" "$CHECKOUT")"
assert_fail "resolve fails for an unknown name" \
  _worktree_diff_resolve_name nope "$CREATED" "$CHECKOUT"
assert_fail "resolve fails for a dir without a .git pointer" \
  _worktree_diff_resolve_name plain "$CREATED" "$CHECKOUT"

# --- Part E: real git worktrees (validates the parse on git's real layout) ---
if ! command -v git >/dev/null 2>&1; then
  print -r -- "  skip: git not available, skipping real-worktree assertions"
else
  MAIN="$FIX/realmain"
  git init -q -b main "$MAIN"
  git -C "$MAIN" config user.email "t@example.com"
  git -C "$MAIN" config user.name "Test"
  print -r -- "hello" > "$MAIN/file.txt"
  git -C "$MAIN" add -A
  git -C "$MAIN" commit -qm "init"

  git -C "$MAIN" worktree add -q -b feat/a "$CREATED/ra" >/dev/null 2>&1
  git -C "$MAIN" worktree add -q -b feat/b "$CREATED/rb" >/dev/null 2>&1

  ra_repo="$(_worktree_diff_main_repo "$CREATED/ra")"
  rb_repo="$(_worktree_diff_main_repo "$CREATED/rb")"
  assert_eq "real worktree resolves to its main repo basename" "realmain" "${ra_repo:t}"
  assert_eq "two worktrees of one repo resolve to the same main repo" "$ra_repo" "$rb_repo"
  assert_ok "real same-repo worktrees pass the same-repo check" \
    _worktree_diff_same_repo "$CREATED/ra" "$CREATED/rb"

  # A second real repo with its own worktree must NOT share the repo.
  MAIN2="$FIX/realmain2"
  git init -q -b main "$MAIN2"
  git -C "$MAIN2" config user.email "t@example.com"
  git -C "$MAIN2" config user.name "Test"
  print -r -- "hi" > "$MAIN2/f.txt"
  git -C "$MAIN2" add -A
  git -C "$MAIN2" commit -qm "init"
  git -C "$MAIN2" worktree add -q -b feat/c "$CHECKOUT/rc" >/dev/null 2>&1

  assert_fail "worktrees from two different real repos do not share a repo" \
    _worktree_diff_same_repo "$CREATED/ra" "$CHECKOUT/rc"

  # Resolve-by-name also works against a real worktree pointer.
  exp_ra="$CREATED/ra"; exp_ra="${exp_ra:A}"
  assert_eq "resolve a real worktree by name" \
    "$exp_ra" "$(_worktree_diff_resolve_name ra "$CREATED" "$CHECKOUT")"
fi

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
