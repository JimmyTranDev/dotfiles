#!/usr/bin/env zsh
# Tests for agent_commit_argv in utils/utility.sh -- the per-agent argv that the
# Alt c launcher (open_ai_commit.sh) uses to make the resolved AI agent auto-run
# the /commit command. opencode takes the prompt via a --prompt flag; storecode
# (an Enterprise Claude Code wrapper) takes it as a positional arg, so the two
# agents need different argv. The helper prints one token per line so the caller
# reads it straight into an array.
#
# Run: zsh etc/scripts/tests/test_agent_commit_argv.zsh

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

# Read the helper's newline-separated output into an array, then join with a
# literal '|' so the exact token sequence (and count) is asserted in one shot.
argv_joined() {
  local agent="$1"
  local -a out
  out=("${(@f)$(agent_commit_argv "$agent")}")
  print -r -- "${(j:|:)out}"
}

# --- opencode: prompt goes through the --prompt flag --------------------------
assert_eq "opencode -> --prompt then /commit" \
  "--prompt|/commit" "$(argv_joined opencode)"

# --- storecode: prompt is a positional arg (Claude Code passthrough) ----------
assert_eq "storecode -> positional /commit" \
  "/commit" "$(argv_joined storecode)"

# --- unknown / empty agent falls back to the positional form (safe default) ---
assert_eq "unknown agent -> positional /commit" \
  "/commit" "$(argv_joined some-other-agent)"
assert_eq "empty agent -> positional /commit" \
  "/commit" "$(argv_joined '')"

print -r --
print -r -- "Passed: $PASS  Failed: $FAIL"
(( FAIL == 0 )) || exit 1
