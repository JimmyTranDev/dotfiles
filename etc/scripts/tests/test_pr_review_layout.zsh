#!/usr/bin/env zsh
# Tests for the three pure helpers behind the Alt g "open a PR review" launcher
# (etc/scripts/src/zellij/open_pr_review.sh), all defined in utils/utility.sh so
# they are sourceable and unit-testable without zellij/fzf/gh:
#
#   pr_number_from_selection  - pull the PR number out of a `gh pr list` fzf row
#                               ("#123  title  (author)" -> "123").
#   folder_name_from_branch   - the wcheckout folder name for a head branch
#                               ("feat/foo" -> "foo"), matching the worktree
#                               machinery so reuse-detection lines up.
#   render_pr_review_layout   - stamp the PR number into a throwaway copy of
#                               layouts/pr-review.kdl and print its path, so the
#                               opencode pane launches `/review-pr <N>`.
#
# Run: zsh etc/scripts/tests/test_pr_review_layout.zsh

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/utility.sh"

LAYOUT_SRC="$REPO_ROOT/src/zellij/layouts/pr-review.kdl"

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

# --- pr_number_from_selection ------------------------------------------------
assert_eq "parses the number from a full gh pr list row" \
  "123" "$(pr_number_from_selection '#123  Add the thing  (octocat)')"

assert_eq "parses a single-digit PR number" \
  "7" "$(pr_number_from_selection '#7  Tiny fix  (someone)')"

assert_eq "tolerates a row without the leading hash" \
  "42" "$(pr_number_from_selection '42  No hash here  (dev)')"

out="$(pr_number_from_selection 'no number at all' 2>/dev/null)"; rc=$?
assert_eq "a row with no number returns non-zero" "1" "$rc"
assert_eq "a row with no number prints nothing" "" "$out"

out="$(pr_number_from_selection '' 2>/dev/null)"; rc=$?
assert_eq "an empty row returns non-zero" "1" "$rc"

# A title that merely contains digits must not leak into the number.
assert_eq "stops at the first non-digit so the title can't leak in" \
  "9" "$(pr_number_from_selection '#9  bump to v2.3.4  (dev)')"

# --- folder_name_from_branch -------------------------------------------------
assert_eq "strips the first path segment of a slashed branch" \
  "foo" "$(folder_name_from_branch 'feat/foo')"

assert_eq "leaves a flat branch name untouched" \
  "mybranch" "$(folder_name_from_branch 'mybranch')"

assert_eq "keeps the remainder of a deeply nested branch" \
  "foo/bar" "$(folder_name_from_branch 'feat/foo/bar')"

assert_eq "leaves a fork snapshot branch (pr-<n>) untouched" \
  "pr-123" "$(folder_name_from_branch 'pr-123')"

# --- render_pr_review_layout -------------------------------------------------
rendered="$(render_pr_review_layout 123 "$LAYOUT_SRC")"; rc=$?
assert_eq "render returns zero for a numeric PR" "0" "$rc"

if [[ -f "$rendered" ]]; then
  pass "render prints the path to an existing layout file"
  content="$(<"$rendered")"
  if [[ "$content" == *"/review-pr 123"* ]]; then
    pass "rendered layout carries the /review-pr 123 prompt"
  else
    fail "rendered layout carries the /review-pr 123 prompt"
  fi
  if [[ "$content" != *"__PR_NUMBER__"* ]]; then
    pass "rendered layout leaves no __PR_NUMBER__ placeholder behind"
  else
    fail "rendered layout leaves no __PR_NUMBER__ placeholder behind"
  fi
  if [[ "$content" == *'command="opencode"'* && "$content" == *'command="nvim"'* ]]; then
    pass "rendered layout keeps the opencode + nvim split"
  else
    fail "rendered layout keeps the opencode + nvim split"
  fi
  rm -rf "${rendered:h}"
else
  fail "render prints the path to an existing layout file"
fi

out="$(render_pr_review_layout 'abc' "$LAYOUT_SRC" 2>/dev/null)"; rc=$?
assert_eq "render rejects a non-numeric PR with non-zero" "1" "$rc"
assert_eq "render prints nothing for a non-numeric PR" "" "$out"

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
