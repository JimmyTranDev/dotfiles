#!/usr/bin/env zsh
# Tests for last_project_dir in utils/utility.sh — the non-interactive resolver
# behind the "open the LAST selected project" binds (Alt \ opencode-last,
# Alt ' nvim-last). It maps the "[label]" that select_project_dir writes to
# ~/.last_project back to an absolute path (reusing _collect_project_dir_entries
# so the label always matches what the picker stored), bumps that project's
# recency, and fails — non-zero and silent — when no last project is recorded or
# its label no longer resolves, so the caller can fall back to the fzf picker.
#
# Run: zsh etc/scripts/tests/test_last_project_dir.zsh

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/utility.sh"

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

zmodload -F zsh/stat b:zstat 2>/dev/null
sort_desc() { sort -t$'\t' -k1,1 -rn; }

reset_mtimes() {
  touch -t 202401010000 "$PROG/orgA/repo1/.git"
  touch -t 202401020000 "$PROG/orgA/repo2/.git"
  touch -t 202401030000 "$CHECKOUT/wt-beta/.git"
  touch -t 202401040000 "$CREATED/wt-alpha/.git"
}

# --- Fixture -----------------------------------------------------------------
FIX="$(mktemp -d "${TMPDIR:-/tmp}/lastproj.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

PROG="$FIX/Programming"
CREATED="$PROG/wcreated"
CHECKOUT="$PROG/wcheckout"
LAST="$FIX/.last_project"

mkdir -p "$PROG/orgA/repo1/.git" "$PROG/orgA/repo2/.git"
mkdir -p "$CREATED/wt-alpha" "$CHECKOUT/wt-beta"
print -r -- "gitdir: /elsewhere/orgA/repo1/.git/worktrees/wt-alpha" > "$CREATED/wt-alpha/.git"
print -r -- "gitdir: /elsewhere/orgA/repo2/.git/worktrees/wt-beta" > "$CHECKOUT/wt-beta/.git"
reset_mtimes

# --- Resolves a project label to its absolute path ---------------------------
print -rn -- "[orgA] repo1" > "$LAST"
assert_eq "resolves an [org] project label to its absolute path" \
  "$PROG/orgA/repo1" "$(last_project_dir "$PROG" "$CREATED" "$CHECKOUT" "$LAST")"

# --- Resolves worktree labels (wcreated / wcheckout) -------------------------
print -rn -- "[wcreated] wt-alpha" > "$LAST"
assert_eq "resolves a [wcreated] worktree label to its path" \
  "$CREATED/wt-alpha" "$(last_project_dir "$PROG" "$CREATED" "$CHECKOUT" "$LAST")"

print -rn -- "[wcheckout] wt-beta" > "$LAST"
assert_eq "resolves a [wcheckout] worktree label to its path" \
  "$CHECKOUT/wt-beta" "$(last_project_dir "$PROG" "$CREATED" "$CHECKOUT" "$LAST")"

# --- No last project recorded -> non-zero, no output -------------------------
rm -f "$LAST"
out="$(last_project_dir "$PROG" "$CREATED" "$CHECKOUT" "$LAST" 2>/dev/null)"; rc=$?
assert_eq "missing ~/.last_project returns non-zero" "1" "$rc"
assert_eq "missing ~/.last_project prints nothing" "" "$out"

print -rn -- "" > "$LAST"
out="$(last_project_dir "$PROG" "$CREATED" "$CHECKOUT" "$LAST" 2>/dev/null)"; rc=$?
assert_eq "empty ~/.last_project returns non-zero" "1" "$rc"
assert_eq "empty ~/.last_project prints nothing" "" "$out"

# --- Stale label (no longer resolves) -> non-zero ----------------------------
print -rn -- "[orgA] ghost" > "$LAST"
out="$(last_project_dir "$PROG" "$CREATED" "$CHECKOUT" "$LAST" 2>/dev/null)"; rc=$?
assert_eq "unresolvable label returns non-zero" "1" "$rc"
assert_eq "unresolvable label prints nothing" "" "$out"

# --- Recency bump: re-opening floats the project to the top ------------------
# repo1 is the OLDEST entry after a reset; resolving it must bump it to newest.
reset_mtimes
print -rn -- "[orgA] repo1" > "$LAST"
last_project_dir "$PROG" "$CREATED" "$CHECKOUT" "$LAST" >/dev/null
top="$(_collect_project_dir_entries "$PROG" "$CREATED" "$CHECKOUT" | sort_desc | head -1 | cut -f2)"
assert_eq "resolving the last project bumps it to the top of the listing" \
  "[orgA] repo1" "$top"

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
