#!/usr/bin/env zsh
# Regression tests for the Alt p "open project sidebar" launcher
# (etc/scripts/src/zellij/open_project_tool.sh). Alt p must open the 30% chosen
# tool / 70% nvim SPLIT LAYOUT — the sidebar — in a new tab, NOT a single stacked
# pane. The pure render helper lives in utils/utility.sh so it is sourceable and
# unit-testable without zellij/fzf:
#
#   render_sidebar_layout - stamp the chosen sidebar tool into a throwaway copy of
#                           layouts/opencode-sidebar.kdl and print its path, so the
#                           left sidebar pane runs that tool beside a 70% nvim pane.
#                           "empty" yields a plain shell pane.
#
# This guards against the recurring regression where Alt p gets repointed to a
# single stacked pane and the 30%/70% sidebar layout is dropped (commits
# 4193d56 then again c565d83).
#
# Run: zsh etc/scripts/tests/test_sidebar_layout.zsh

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/utility.sh"

LAYOUT_SRC="$REPO_ROOT/src/zellij/layouts/opencode-sidebar.kdl"

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

# --- the sidebar layout file must exist and be a 30%/70% split ---------------
if [[ -f "$LAYOUT_SRC" ]]; then
  pass "opencode-sidebar.kdl layout exists"
  src_content="$(<"$LAYOUT_SRC")"
  if [[ "$src_content" == *'size="30%"'* && "$src_content" == *'size="70%"'* ]]; then
    pass "layout defines a 30% / 70% split"
  else
    fail "layout defines a 30% / 70% split"
  fi
  if [[ "$src_content" == *'command="nvim"'* ]]; then
    pass "layout's 70% pane runs nvim"
  else
    fail "layout's 70% pane runs nvim"
  fi
else
  fail "opencode-sidebar.kdl layout exists"
fi

# --- render_sidebar_layout: opencode default ---------------------------------
rendered="$(render_sidebar_layout opencode "$LAYOUT_SRC")"; rc=$?
assert_eq "render returns zero for the opencode tool" "0" "$rc"

if [[ -f "$rendered" ]]; then
  pass "render prints the path to an existing layout file"
  content="$(<"$rendered")"
  if [[ "$content" == *'command="opencode"'* && "$content" == *'command="nvim"'* ]]; then
    pass "rendered layout keeps the opencode sidebar + nvim split"
  else
    fail "rendered layout keeps the opencode sidebar + nvim split"
  fi
  if [[ "$content" == *'size="30%"'* && "$content" == *'size="70%"'* ]]; then
    pass "rendered layout keeps the 30% / 70% split"
  else
    fail "rendered layout keeps the 30% / 70% split"
  fi
  rm -rf "${rendered:h}"
else
  fail "render prints the path to an existing layout file"
fi

# --- render_sidebar_layout: an arbitrary tool is templated into the sidebar --
rendered="$(render_sidebar_layout gh-dash "$LAYOUT_SRC")"; rc=$?
assert_eq "render returns zero for a non-opencode tool" "0" "$rc"
if [[ -f "$rendered" ]]; then
  content="$(<"$rendered")"
  if [[ "$content" == *'command="gh-dash"'* ]]; then
    pass "rendered layout runs the chosen tool in the sidebar"
  else
    fail "rendered layout runs the chosen tool in the sidebar"
  fi
  rm -rf "${rendered:h}"
else
  fail "render (gh-dash) prints the path to an existing layout file"
fi

# --- render_sidebar_layout: "empty" yields a plain shell sidebar pane --------
rendered="$(render_sidebar_layout empty "$LAYOUT_SRC")"; rc=$?
assert_eq "render returns zero for the empty tool" "0" "$rc"
if [[ -f "$rendered" ]]; then
  content="$(<"$rendered")"
  if [[ "$content" != *'command="opencode"'* ]]; then
    pass "empty tool drops the opencode command from the sidebar"
  else
    fail "empty tool drops the opencode command from the sidebar"
  fi
  if [[ "$content" == *'command="nvim"'* ]]; then
    pass "empty tool keeps the nvim editor pane"
  else
    fail "empty tool keeps the nvim editor pane"
  fi
  rm -rf "${rendered:h}"
else
  fail "render (empty) prints the path to an existing layout file"
fi

# --- render_sidebar_layout: missing source layout is rejected ----------------
out="$(render_sidebar_layout opencode "/no/such/layout.kdl" 2>/dev/null)"; rc=$?
assert_eq "render rejects a missing source layout with non-zero" "1" "$rc"
assert_eq "render prints nothing for a missing source layout" "" "$out"

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
