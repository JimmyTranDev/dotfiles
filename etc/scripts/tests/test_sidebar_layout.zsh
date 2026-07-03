#!/usr/bin/env zsh
# Regression tests for the Alt p "open project sidebar" launcher
# (etc/scripts/src/zellij/open_project_tool.sh). Alt p must open the 30% opencode
# / 70% nvim SPLIT LAYOUT — the sidebar — in a new tab, NOT a single stacked
# pane, and it must do so with NO tool prompt: the sidebar is always opencode and
# the main pane is always nvim (the fzf tool-picker was removed).
#
# Two kinds of checks:
#   1. The sidebar layout file (layouts/opencode-sidebar.kdl) is a 30%/70%
#      opencode+nvim split with nvim as the focused (main) pane.
#   2. The launcher script opens that layout directly and no longer prompts for a
#      sidebar tool — it must NOT reference select_pane_tool / save_pane_tool /
#      render_sidebar_layout.
#
# This guards against the recurring regression where Alt p gets repointed to a
# single stacked pane and the 30%/70% sidebar layout is dropped (commits
# 4193d56 then again c565d83), and against the tool-picker creeping back in.
#
# Run: zsh etc/scripts/tests/test_sidebar_layout.zsh

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/utility.sh"

LAYOUT_SRC="$REPO_ROOT/src/zellij/layouts/opencode-sidebar.kdl"
LAUNCHER="$REPO_ROOT/etc/scripts/src/zellij/open_project_tool.sh"

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

# --- the sidebar layout file must be a 30%/70% opencode+nvim split -----------
if [[ -f "$LAYOUT_SRC" ]]; then
  pass "opencode-sidebar.kdl layout exists"
  src_content="$(<"$LAYOUT_SRC")"
  if [[ "$src_content" == *'size="30%"'* && "$src_content" == *'size="70%"'* ]]; then
    pass "layout defines a 30% / 70% split"
  else
    fail "layout defines a 30% / 70% split"
  fi
  if [[ "$src_content" == *'command="nvim"'* ]]; then
    pass "layout's 70% pane runs nvim (main)"
  else
    fail "layout's 70% pane runs nvim (main)"
  fi
  if [[ "$src_content" == *'command="opencode"'* ]]; then
    pass "layout's 30% sidebar runs opencode"
  else
    fail "layout's 30% sidebar runs opencode"
  fi
  # nvim is the main pane, so it must be the focused one on start.
  if [[ "$src_content" == *'command="nvim"'*'focus=true'* || "$src_content" == *'focus=true'*'command="nvim"'* ]]; then
    pass "layout focuses the nvim (main) pane on start"
  else
    fail "layout focuses the nvim (main) pane on start"
  fi
else
  fail "opencode-sidebar.kdl layout exists"
fi

# --- the Alt p launcher opens the layout with NO tool prompt -----------------
if [[ -f "$LAUNCHER" ]]; then
  pass "open_project_tool.sh launcher exists"
  launcher_content="$(<"$LAUNCHER")"

  # No sidebar-tool prompt: the fzf tool-picker and its per-project save must be
  # gone so Alt p goes straight from project pick to the opencode+nvim layout.
  if [[ "$launcher_content" != *'select_pane_tool'* ]]; then
    pass "launcher does not prompt for a sidebar tool (no select_pane_tool)"
  else
    fail "launcher does not prompt for a sidebar tool (no select_pane_tool)"
  fi
  if [[ "$launcher_content" != *'save_pane_tool'* ]]; then
    pass "launcher does not save a per-project tool (no save_pane_tool)"
  else
    fail "launcher does not save a per-project tool (no save_pane_tool)"
  fi
  # The tool is fixed (opencode), so no throwaway layout render is needed.
  if [[ "$launcher_content" != *'render_sidebar_layout'* ]]; then
    pass "launcher opens the layout directly (no render_sidebar_layout)"
  else
    fail "launcher opens the layout directly (no render_sidebar_layout)"
  fi
  # It still opens the opencode+nvim sidebar layout in a new tab.
  if [[ "$launcher_content" == *'opencode-sidebar.kdl'* ]]; then
    pass "launcher opens the opencode-sidebar.kdl layout"
  else
    fail "launcher opens the opencode-sidebar.kdl layout"
  fi
  if [[ "$launcher_content" == *'new-tab'* && "$launcher_content" == *'--layout'* ]]; then
    pass "launcher opens the layout in a new tab"
  else
    fail "launcher opens the layout in a new tab"
  fi
  # It still picks a project first.
  if [[ "$launcher_content" == *'select_project_dir'* ]]; then
    pass "launcher still picks a project (select_project_dir)"
  else
    fail "launcher still picks a project (select_project_dir)"
  fi
else
  fail "open_project_tool.sh launcher exists"
fi

# --- render_sidebar_layout still renders a valid opencode+nvim split ---------
# The helper is retained (out of scope to remove) and stays a useful layout
# integrity check: stamping opencode keeps the opencode+nvim 30%/70% split.
rendered="$(render_sidebar_layout opencode "$LAYOUT_SRC")"; rc=$?
assert_eq "render returns zero for the opencode tool" "0" "$rc"
if [[ -f "$rendered" ]]; then
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

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
