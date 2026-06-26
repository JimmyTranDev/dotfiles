#!/usr/bin/env zsh
# Tests for the recency-sorted project picker core in utils/utility.sh:
#   _stat_mtime, _recency_mtime, bump_project_recency, _collect_project_dir_entries
#
# These back the shared select_project_dir() picker (Alt ] opencode, Alt [ nvim,
# Alt p sidebar, mass_tab, side), which now lists projects/worktrees
# most-recently-used first (by .git/dir mtime). The fzf/cd glue inside
# select_project_dir itself is interactive and is not unit-tested here; this
# pins the pure, deterministic core: mtime reading, the .git->dir fallback,
# the recency bump, and what gets collected, labelled, and ordered.
#
# Run: zsh etc/scripts/tests/test_select_project_recency.zsh

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

zmodload -F zsh/stat b:zstat 2>/dev/null
sort_desc() { sort -t$'\t' -k1,1 -rn; }

# --- Fixture -----------------------------------------------------------------
FIX="$(mktemp -d "${TMPDIR:-/tmp}/sprec.XXXXXX")"
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

# --- _stat_mtime: portable mtime matches zstat -------------------------------
assert_eq "_stat_mtime matches zstat for a .git dir" \
  "$(zstat +mtime "$PROG/orgA/repo1/.git")" "$(_stat_mtime "$PROG/orgA/repo1/.git")"
assert_eq "_stat_mtime matches zstat for a .git file" \
  "$(zstat +mtime "$CREATED/wt-alpha/.git")" "$(_stat_mtime "$CREATED/wt-alpha/.git")"
assert_eq "_stat_mtime on a missing path is empty/non-fatal" \
  "" "$(_stat_mtime "$PROG/does/not/exist" 2>/dev/null)"

# --- _stat_mtime caches the detected stat flavor (one fork/call, not two) -----
# On BSD/macOS the old "stat -c %Y || stat -f %m" form forked twice per call
# (the GNU -c form always fails first there). The flavor is now probed once and
# cached in _STAT_MTIME_FMT so every later call forks a single stat.
known_flavor() { [[ "${_STAT_MTIME_FMT:-}" == gnu || "${_STAT_MTIME_FMT:-}" == bsd ]] && echo yes || echo no; }

unset _STAT_MTIME_FMT
_stat_mtime "$PROG/orgA/repo1/.git" >/dev/null
assert_eq "_stat_mtime caches a known stat flavor (gnu/bsd) after first use" \
  "yes" "$(known_flavor)"

# Detection probes "/", so even a cold-cache call on a MISSING path resolves the
# flavor and stays empty/non-fatal.
unset _STAT_MTIME_FMT
cold_miss="$(_stat_mtime "$PROG/does/not/exist" 2>/dev/null)"
assert_eq "_stat_mtime cold-cache on a missing path still prints nothing" \
  "" "$cold_miss"

unset _STAT_MTIME_FMT
_stat_mtime "$PROG/does/not/exist" >/dev/null 2>&1
assert_eq "_stat_mtime caches the flavor even when the first path is missing" \
  "yes" "$(known_flavor)"

# --- _recency_mtime: .git mtime, else dir mtime, else 0 ----------------------
assert_eq "_recency_mtime uses the .git mtime when present (repo)" \
  "$(zstat +mtime "$PROG/orgA/repo1/.git")" "$(_recency_mtime "$PROG/orgA/repo1")"
assert_eq "_recency_mtime uses the .git file mtime for a worktree" \
  "$(zstat +mtime "$CREATED/wt-alpha/.git")" "$(_recency_mtime "$CREATED/wt-alpha")"

mkdir -p "$PROG/orgA/plainproj"
touch -t 202401060000 "$PROG/orgA/plainproj"
assert_eq "_recency_mtime falls back to the directory mtime when no .git" \
  "$(zstat +mtime "$PROG/orgA/plainproj")" "$(_recency_mtime "$PROG/orgA/plainproj")"
assert_eq "_recency_mtime is 0 for a non-existent path" \
  "0" "$(_recency_mtime "$PROG/nope")"

# --- _collect_project_dir_entries: content -----------------------------------
# (plainproj exists from the _recency_mtime section above -> 5 entries now)
entries="$(_collect_project_dir_entries "$PROG" "$CREATED" "$CHECKOUT")"

assert_eq "collects 5 entries (3 projects + 2 worktrees)" \
  "5" "$(print -r -- "$entries" | grep -c .)"

assert_contains "project repo1 labelled [orgA] repo1 with its absolute path" \
  "$entries" $'\t[orgA] repo1\t'"$PROG/orgA/repo1"
assert_contains "project repo2 labelled [orgA] repo2 with its absolute path" \
  "$entries" $'\t[orgA] repo2\t'"$PROG/orgA/repo2"
assert_contains "worktree wt-alpha labelled by its container [wcreated]" \
  "$entries" $'\t[wcreated] wt-alpha\t'"$CREATED/wt-alpha"
assert_contains "worktree wt-beta labelled by its container [wcheckout]" \
  "$entries" $'\t[wcheckout] wt-beta\t'"$CHECKOUT/wt-beta"
assert_contains "non-git project folder is still listed (dir mtime fallback)" \
  "$entries" $'\t[orgA] plainproj\t'"$PROG/orgA/plainproj"

# --- Sort: most-recently-used first ------------------------------------------
# plainproj (01-06) is newest, then wt-alpha (01-04), wt-beta (01-03),
# repo2 (01-02), repo1 (01-01).
sorted_labels="$(_collect_project_dir_entries "$PROG" "$CREATED" "$CHECKOUT" | sort_desc | cut -f2)"
expected_order=$'[orgA] plainproj\n[wcreated] wt-alpha\n[wcheckout] wt-beta\n[orgA] repo2\n[orgA] repo1'
assert_eq "sorted by mtime descending (most recent first)" "$expected_order" "$sorted_labels"

# --- Recency bump floats an entry to the top ---------------------------------
bump_project_recency "$PROG/orgA/repo1" # repo1 now newest
bumped_first="$(_collect_project_dir_entries "$PROG" "$CREATED" "$CHECKOUT" | sort_desc | head -1 | cut -f2)"
assert_eq "bump_project_recency floats the chosen project to the top" \
  "[orgA] repo1" "$bumped_first"

# --- bump_project_recency touches .git when present, else the directory -------
mkdir -p "$PROG/orgB/grepo/.git"
touch -t 202001010000 "$PROG/orgB/grepo/.git"
git_before="$(zstat +mtime "$PROG/orgB/grepo/.git")"
bump_project_recency "$PROG/orgB/grepo"
git_after="$(zstat +mtime "$PROG/orgB/grepo/.git")"
assert_gt "bump_project_recency touches .git when present" "$git_after" "$git_before"

mkdir -p "$PROG/orgB/plaindir"
touch -t 202001010000 "$PROG/orgB/plaindir"
dir_before="$(zstat +mtime "$PROG/orgB/plaindir")"
bump_project_recency "$PROG/orgB/plaindir"
dir_after="$(zstat +mtime "$PROG/orgB/plaindir")"
assert_gt "bump_project_recency touches the directory when no .git" "$dir_after" "$dir_before"

# --- Resilience: a missing container dir is skipped silently -----------------
res_count="$(_collect_project_dir_entries "$PROG" "$CREATED" "$PROG/nope" 2>/dev/null | grep -c .)"
assert_eq "missing container dir is skipped without error (wt-beta drops, 6 remain)" \
  "6" "$res_count"

# --- Summary -----------------------------------------------------------------
print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
