#!/usr/bin/env zsh
# Tests for the worktree-create branch-name decision logic.
#
# Run: zsh etc/scripts/tests/test_worktree_create.zsh
#
# cmd_create itself is interactive (fzf / git worktree add / acli / cd) and is
# not unit-tested here. This pins the pure, deterministic core that the optional
# -JIRA behavior depends on: compute_branch_name — which honors a JIRA key when
# one is given and otherwise derives a sanitized branch name from the input.
# It also source-greps create.sh to guard the "no dedicated JIRA prompt" rule.

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/src/worktrees/config.sh"
source "$REPO_ROOT/etc/scripts/utils/worktree_core.sh"

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

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    pass "$desc"
  else
    fail "$desc"
    print -r -- "    unexpectedly present: [$needle]"
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

# --- compute_branch_name: JIRA key is honored when supplied -------------------
assert_eq "JIRA key + summary -> <KEY>-<slug(summary)>, key case preserved" \
  "ABC-123-add-login-button" "$(compute_branch_name "ABC-123" "Add login button")"

assert_eq "JIRA key + messy summary is slugified and trimmed" \
  "PROJ-1-fix-the-thing" "$(compute_branch_name "PROJ-1" "Fix: the thing!")"

assert_eq "JIRA key, no summary -> bare key" \
  "ABC-123" "$(compute_branch_name "ABC-123" "")"

assert_eq "JIRA key whose summary slugifies to empty -> bare key" \
  "ABC-9" "$(compute_branch_name "ABC-9" "!!!")"

# --- compute_branch_name: anything else is a sanitized branch name -----------
assert_eq "non-key input is sanitized into a branch name" \
  "my-feature" "$(compute_branch_name "my feature!" "")"

assert_eq "slashes in a non-key name become dashes" \
  "feature-login" "$(compute_branch_name "feature/login" "")"

assert_eq "lowercase ticket-like input is NOT treated as a JIRA key" \
  "abc-123" "$(compute_branch_name "abc-123" "")"

assert_eq "empty input yields an empty branch name (caller aborts)" \
  "" "$(compute_branch_name "" "")"

# --- Regression: create.sh must not force a dedicated JIRA prompt -------------
CREATE_SH="$REPO_ROOT/etc/scripts/src/worktrees/commands/create.sh"
create_src="$(< "$CREATE_SH")"

assert_not_contains "create.sh no longer asks specifically for a JIRA ticket" \
  "$create_src" "Enter JIRA ticket"
assert_contains "create.sh prompts once for a branch name (JIRA optional)" \
  "$create_src" "Enter branch name"

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
