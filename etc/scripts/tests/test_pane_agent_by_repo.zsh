#!/usr/bin/env zsh
# Tests for the repo -> AI-agent routing in utils/utility.sh — the logic behind
# Alt ] (open_ai_chat.sh) choosing opencode vs storecode per repo. A repo
# whose git `origin` owner is in PERSONAL_AGENT_ORGS (Jimmy's personal orgs)
# opens opencode; every other repo — including one with no origin — opens
# storecode.
#
# Run: zsh etc/scripts/tests/test_pane_agent_by_repo.zsh

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

FIX="$(mktemp -d "${TMPDIR:-/tmp}/paneagent.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# Build a throwaway git repo at $FIX/<name> whose origin is <url>. No origin is
# added when <url> is empty. Prints the repo path.
make_repo() {
  local name="$1" url="$2"
  local repo="$FIX/$name"
  git init -q "$repo"
  [[ -n "$url" ]] && git -C "$repo" remote add origin "$url"
  printf '%s' "$repo"
}

# --- _owner_from_remote_url: pure URL -> owner parsing ------------------------
assert_eq "ssh scp-form url -> owner" \
  "storebrand-digital" "$(_owner_from_remote_url 'git@github.com:storebrand-digital/foo.git')"
assert_eq "https url with .git -> owner" \
  "storebrand-digital" "$(_owner_from_remote_url 'https://github.com/storebrand-digital/foo.git')"
assert_eq "https url without .git -> owner" \
  "JimmyTranDev" "$(_owner_from_remote_url 'https://github.com/JimmyTranDev/dotfiles')"
assert_eq "ssh:// url -> owner" \
  "JimmyTranDev" "$(_owner_from_remote_url 'ssh://git@github.com/JimmyTranDev/dotfiles.git')"

out="$(_owner_from_remote_url '' 2>/dev/null)"; rc=$?
assert_eq "empty url returns non-zero" "1" "$rc"
assert_eq "empty url prints nothing" "" "$out"

out="$(_owner_from_remote_url 'garbage-no-slash' 2>/dev/null)"; rc=$?
assert_eq "unparseable url returns non-zero" "1" "$rc"

# --- github_remote_owner: reads a repo's origin ------------------------------
work_repo="$(make_repo work 'git@github.com:storebrand-digital/api.git')"
personal_repo="$(make_repo personal 'https://github.com/JimmyTranDev/dotfiles.git')"
no_origin_repo="$(make_repo noorigin '')"

assert_eq "owner from a work repo's ssh origin" \
  "storebrand-digital" "$(github_remote_owner "$work_repo")"
assert_eq "owner from a personal repo's https origin" \
  "JimmyTranDev" "$(github_remote_owner "$personal_repo")"

out="$(github_remote_owner "$no_origin_repo" 2>/dev/null)"; rc=$?
assert_eq "no origin returns non-zero" "1" "$rc"

# --- agent_for_owner: owner -> agent (default PERSONAL_AGENT_ORGS) ------------
assert_eq "personal org owner -> opencode" \
  "opencode" "$(agent_for_owner jimmytrandev)"
assert_eq "personal org owner is case-insensitive" \
  "opencode" "$(agent_for_owner JimmyTranDev)"
assert_eq "work org owner -> storecode" \
  "storecode" "$(agent_for_owner storebrand-digital)"
assert_eq "unknown owner -> storecode" \
  "storecode" "$(agent_for_owner some-other-org)"
assert_eq "empty owner -> storecode" \
  "storecode" "$(agent_for_owner '')"

# --- agent_for_owner: PERSONAL_AGENT_ORGS is overridable ---------------------
saved_orgs=("${PERSONAL_AGENT_ORGS[@]}")
PERSONAL_AGENT_ORGS=(acme-corp)
assert_eq "override: added org -> opencode" \
  "opencode" "$(agent_for_owner acme-corp)"
assert_eq "override: former default org -> storecode" \
  "storecode" "$(agent_for_owner jimmytrandev)"
PERSONAL_AGENT_ORGS=("${saved_orgs[@]}")

# --- resolve_repo_agent: repo dir -> agent -----------------------------------
assert_eq "personal repo resolves to opencode" \
  "opencode" "$(resolve_repo_agent "$personal_repo")"
assert_eq "work repo resolves to storecode" \
  "storecode" "$(resolve_repo_agent "$work_repo")"
assert_eq "repo with no origin resolves to storecode" \
  "storecode" "$(resolve_repo_agent "$no_origin_repo")"

print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
