#!/usr/bin/env zsh
# Tests for _collect_project_worktree_entries — the shared discovery used by the
# unified project+worktree pickers (^f single-select, ^[f multi-select).
#
# Run: zsh etc/scripts/tests/test_select_project_worktree.zsh
#
# The picker glue (fzf / cd / zle) is interactive and not unit-tested here; this
# pins the pure, deterministic core: what gets listed, how it is labelled, and
# the "recent used/created" ordering.

emulate -L zsh
set -u

SELF="${0:A}"
REPO_ROOT="${SELF:h:h:h:h}" # etc/scripts/tests/<file> -> repo root

source "$REPO_ROOT/etc/scripts/utils/utility.sh"
source "$REPO_ROOT/etc/scripts/src/zshrc/project_worktree_common.sh"

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

assert_gt() {
  local desc="$1" a="$2" b="$3"
  if (( a > b )); then
    pass "$desc"
  else
    fail "$desc"
    print -r -- "    not greater: [$a] !> [$b]"
  fi
}

sort_desc() { sort -t$'\t' -k1,1 -rn; }

zmodload -F zsh/stat b:zstat 2>/dev/null

# --- Fixture -----------------------------------------------------------------
FIX="$(mktemp -d "${TMPDIR:-/tmp}/sptw.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

PROG="$FIX/Programming"
CREATED="$PROG/wcreated"
CHECKOUT="$PROG/wcheckout"

mkdir -p "$PROG/orgA/repo1/.git" "$PROG/orgA/repo2/.git"
mkdir -p "$CREATED/wt-alpha" "$CHECKOUT/wt-beta"
print -r -- "gitdir: /elsewhere/orgA/repo1/.git/worktrees/wt-alpha" > "$CREATED/wt-alpha/.git"
print -r -- "gitdir: /elsewhere/orgA/repo2/.git/worktrees/wt-beta" > "$CHECKOUT/wt-beta/.git"

# Deterministic mtimes (oldest -> newest): repo1 < repo2 < wt-beta < wt-alpha
touch -t 202401010000 "$PROG/orgA/repo1/.git"
touch -t 202401020000 "$PROG/orgA/repo2/.git"
touch -t 202401030000 "$CHECKOUT/wt-beta/.git"
touch -t 202401040000 "$CREATED/wt-alpha/.git"

# --- Collection content ------------------------------------------------------
entries="$(_collect_project_worktree_entries "$PROG" "$CREATED" "$CHECKOUT")"

assert_eq "collects 4 entries (2 projects + 2 worktrees)" \
  "4" "$(print -r -- "$entries" | grep -c .)"

assert_contains "project repo1 labelled [orgA] repo1 with its path" \
  "$entries" $'\t[orgA] repo1\t'"$PROG/orgA/repo1"
assert_contains "project repo2 labelled [orgA] repo2 with its path" \
  "$entries" $'\t[orgA] repo2\t'"$PROG/orgA/repo2"
assert_contains "worktree wt-alpha labelled by parent repo [repo1]" \
  "$entries" $'\t[repo1] wt-alpha\t'"$CREATED/wt-alpha"
assert_contains "worktree wt-beta labelled by parent repo [repo2]" \
  "$entries" $'\t[repo2] wt-beta\t'"$CHECKOUT/wt-beta"

# --- Sort: recent created/used first -----------------------------------------
sorted_labels="$(_collect_project_worktree_entries "$PROG" "$CREATED" "$CHECKOUT" | sort_desc | cut -f2)"
expected_order=$'[repo1] wt-alpha\n[repo2] wt-beta\n[orgA] repo2\n[orgA] repo1'
assert_eq "sorted by mtime descending (newest first)" "$expected_order" "$sorted_labels"

# --- Recency bump: touching .git floats an entry to the top ------------------
touch -t 202401050000 "$PROG/orgA/repo1/.git" # repo1 now newest
bumped_first="$(_collect_project_worktree_entries "$PROG" "$CREATED" "$CHECKOUT" | sort_desc | head -1 | cut -f2)"
assert_eq "touching .git bumps the entry to the top (recently used)" \
  "[orgA] repo1" "$bumped_first"

# --- Resilience: a missing worktree dir is skipped silently ------------------
res_count="$(_collect_project_worktree_entries "$PROG" "$CREATED" "$PROG/nope" 2>/dev/null | grep -c .)"
assert_eq "missing worktree dir is skipped without error (3 remain)" "3" "$res_count"

# --- Non-git project folder still listed (dir mtime fallback) ----------------
mkdir -p "$PROG/orgA/plainproj"
touch -t 202401060000 "$PROG/orgA/plainproj"
plain="$(_collect_project_worktree_entries "$PROG" "$CREATED" "$CHECKOUT")"
assert_contains "non-git project folder is still listed (dir mtime fallback)" \
  "$plain" $'\t[orgA] plainproj\t'"$PROG/orgA/plainproj"

# --- _bump_recency touches .git when present, else the directory -------------
mkdir -p "$PROG/orgB/grepo/.git"
touch -t 202001010000 "$PROG/orgB/grepo/.git"
git_before="$(zstat +mtime "$PROG/orgB/grepo/.git")"
_bump_recency "$PROG/orgB/grepo"
git_after="$(zstat +mtime "$PROG/orgB/grepo/.git")"
assert_gt "_bump_recency touches .git when present" "$git_after" "$git_before"

mkdir -p "$PROG/orgB/plaindir"
touch -t 202001010000 "$PROG/orgB/plaindir"
dir_before="$(zstat +mtime "$PROG/orgB/plaindir")"
_bump_recency "$PROG/orgB/plaindir"
dir_after="$(zstat +mtime "$PROG/orgB/plaindir")"
assert_gt "_bump_recency touches the directory when no .git" "$dir_after" "$dir_before"

# --- Regression: widgets must not use zsh special-array names as locals -------
# In zsh, `path cdpath fpath manpath mailpath module_path` are array parameters
# tied to their scalar twins ($PATH, ...). Declaring `local path` (or reading
# into it) wipes $PATH for the whole function, so fzf/sort/touch silently become
# "command not found" and the picker can neither list nor cd. Guard every widget
# against reintroducing that footgun.
typeset -a SPECIAL_PARAMS=(path cdpath fpath manpath mailpath module_path)
uses_special_local() {
  setopt local_options extended_glob
  local file="$1" line code sp
  while IFS= read -r line; do
    code="${line##[[:space:]]#}"          # strip leading whitespace
    [[ "$code" == \#* ]] && continue       # ignore comments (incl. our warnings)
    [[ "$code" == local\ * || "$code" == *read\ * || "$code" == for\ * ]] || continue
    for sp in $SPECIAL_PARAMS; do
      # match the bare word, bounded by non-identifier chars or string ends
      [[ "$code" == (|*[^A-Za-z0-9_])${sp}(|[^A-Za-z0-9_]*) ]] && return 0
    done
  done < "$file"
  return 1
}

for widget in select_project_worktree select_projects_worktrees_multi; do
  wfile="$REPO_ROOT/etc/scripts/src/zshrc/$widget.sh"
  if uses_special_local "$wfile"; then
    fail "$widget declares a zsh special-array name (path/cdpath/...) as a local — would wipe \$PATH"
  else
    pass "$widget keeps zsh special params (\$path etc.) intact"
  fi
done

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
