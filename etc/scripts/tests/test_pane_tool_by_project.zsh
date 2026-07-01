#!/usr/bin/env zsh
# Tests for save_pane_tool / last_pane_tool in utils/utility.sh — the
# per-project pane-tool memory behind Alt p (save the chosen tool when a
# project's pane opens) and Alt ] (open that project's saved tool). The map file
# stores one "<dir>\t<tool>" line per project; saving the same dir replaces its
# line, and looking up an unknown/empty dir fails non-zero and silent so the
# caller can fall back to "empty".
#
# Run: zsh etc/scripts/tests/test_pane_tool_by_project.zsh

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/utility.sh"

typeset -i PASS=0 FAIL=0

pass() { print -r -- "  ok: $1"; (( PASS++ )); }
fail() { print -r -- "FAIL: $1"; (( FAIL++ )); }

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

FIX="$(mktemp -d "${TMPDIR:-/tmp}/panetool.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
MAP="$FIX/.pane_tool_by_project"

# --- save + read back ---------------------------------------------------------
save_pane_tool "nvim" "/home/x/projA" "$MAP"
assert_eq "reads back the tool saved for a project" \
  "nvim" "$(last_pane_tool /home/x/projA "$MAP")"

# --- distinct projects stay independent --------------------------------------
save_pane_tool "opencode" "/home/x/projB" "$MAP"
assert_eq "projA keeps its tool after projB is saved" \
  "nvim" "$(last_pane_tool /home/x/projA "$MAP")"
assert_eq "projB has its own tool" \
  "opencode" "$(last_pane_tool /home/x/projB "$MAP")"

# --- re-saving a project replaces, not duplicates ----------------------------
save_pane_tool "gh-dash" "/home/x/projA" "$MAP"
assert_eq "re-saving projA overwrites its tool" \
  "gh-dash" "$(last_pane_tool /home/x/projA "$MAP")"
lines=$(grep -c "/home/x/projA" "$MAP")
assert_eq "projA appears exactly once in the map" "1" "$lines"

# --- unknown dir -> non-zero, empty ------------------------------------------
out="$(last_pane_tool /home/x/ghost "$MAP" 2>/dev/null)"; rc=$?
assert_eq "unknown project returns non-zero" "1" "$rc"
assert_eq "unknown project prints nothing" "" "$out"

# --- missing map -> non-zero --------------------------------------------------
out="$(last_pane_tool /home/x/projA "$FIX/nope" 2>/dev/null)"; rc=$?
assert_eq "missing map returns non-zero" "1" "$rc"

print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
