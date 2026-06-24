#!/usr/bin/env bash
# Regression tests for sync_secrets.sh upload.
#
# Run: bash etc/scripts/tests/test_sync_secrets.sh
#
# Pins the security-critical contract: the script NEVER logs in or unlocks the
# vault itself (no master-password prompt). It requires an already-unlocked,
# inherited BW_SESSION. When the vault is not unlocked it must fail fast —
# before writing any plaintext tarball to disk — with an actionable message,
# and must not invoke `bw login` or `bw unlock`.
#
# `bw` is replaced with a stub on PATH so the test needs no real vault, no
# master password, and no network.

set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../../.." && pwd)" # tests -> scripts -> etc -> repo
SCRIPT_UNDER_TEST="$REPO_ROOT/etc/scripts/src/sync_secrets.sh"
# Invoke the script under test by absolute path so scenarios can restrict its
# PATH (to hide a dependency) without breaking the interpreter lookup itself.
BASH_BIN="$(command -v bash)"

PASS=0
FAIL=0

pass() {
	echo "  ok: $1"
	PASS=$((PASS + 1))
}
fail() {
	echo "FAIL: $1"
	FAIL=$((FAIL + 1))
}

assert_nonzero_exit() {
	local desc="$1" code="$2"
	if [[ "$code" -ne 0 ]]; then
		pass "$desc"
	else
		fail "$desc (exit was 0)"
	fi
}

assert_no_plaintext_tarball() {
	local desc="$1" dir="$2"
	local leaked
	leaked="$(find "$dir" -type f -name '*.tar*' 2>/dev/null)"
	if [[ -z "$leaked" ]]; then
		pass "$desc"
	else
		fail "$desc"
		echo "    leaked plaintext archive(s):"
		echo "$leaked" | sed 's/^/      /'
	fi
}

assert_output_contains() {
	local desc="$1" haystack="$2" needle="$3"
	if [[ "$haystack" == *"$needle"* ]]; then
		pass "$desc"
	else
		fail "$desc"
		echo "    missing: [$needle]"
	fi
}

assert_zero_exit() {
	local desc="$1" code="$2"
	if [[ "$code" -eq 0 ]]; then
		pass "$desc"
	else
		fail "$desc (exit was $code)"
	fi
}

# Asserts a given bw subcommand was never issued. Anchored so `lock` never
# matches `unlock` and each name matches the whole word only.
assert_bw_subcommand_not_called() {
	local desc="$1" logfile="$2" sub="$3"
	if grep -Eq "^$sub( |\$)" "$logfile" 2>/dev/null; then
		fail "$desc (an unexpected 'bw $sub' was issued)"
	else
		pass "$desc"
	fi
}

# --- Fixture -----------------------------------------------------------------
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sync_secrets.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAKE_SECRETS="$WORK/secrets"
mkdir -p "$FAKE_SECRETS/ssh"
printf 'super-secret-token\n' >"$FAKE_SECRETS/token.env"
printf 'PRIVATE KEY MATERIAL\n' >"$FAKE_SECRETS/ssh/id_ed25519"

# Stub `bw`: authenticated but locked, with no inherited session. `unlock`
# would fail the way the Rust CLI fails on a stale vault — but the script must
# never call it. Every subcommand is logged to $BW_CALL_LOG so a scenario can
# assert that `login`/`unlock` were not issued.
STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"
cat >"$STUB_BIN/bw" <<'STUB'
#!/usr/bin/env bash
[[ -n "${BW_CALL_LOG:-}" ]] && printf '%s\n' "$*" >>"$BW_CALL_LOG"
case "$1" in
status)
	echo '{"serverUrl":null,"lastSync":"now","userEmail":"test@example.com","status":"locked"}'
	;;
unlock)
	echo "ERROR bitwarden_crypto::keys::master_key: error=The decryption operation failed" >&2
	echo "Cryptography error, The decryption operation failed" >&2
	exit 1
	;;
sync)
	exit 0
	;;
*)
	exit 0
	;;
esac
STUB
chmod +x "$STUB_BIN/bw"

# --- Act: upload against a locked vault with no inherited session ------------
OUTPUT_FILE="$WORK/output.log"
A_CALL_LOG="$WORK/a_calls.log"
: >"$A_CALL_LOG"
set +e
SECRETS_DIR="$FAKE_SECRETS" BW_SESSION="" BW_CALL_LOG="$A_CALL_LOG" \
	PATH="$STUB_BIN:$PATH" \
	bash "$SCRIPT_UNDER_TEST" upload </dev/null >"$OUTPUT_FILE" 2>&1
EXIT_CODE=$?
set -e 2>/dev/null || true
OUTPUT="$(cat "$OUTPUT_FILE")"

# --- Assert ------------------------------------------------------------------
echo "sync_secrets.sh upload — a locked vault must fail fast without logging in:"
assert_nonzero_exit "upload fails when the vault is not unlocked" "$EXIT_CODE"
assert_no_plaintext_tarball "no unencrypted tarball is left under SECRETS_DIR" "$FAKE_SECRETS"
assert_output_contains "tells the user to export a BW_SESSION" "$OUTPUT" "BW_SESSION"
assert_bw_subcommand_not_called "never prompts a master-password unlock" "$A_CALL_LOG" "unlock"
assert_bw_subcommand_not_called "never logs in" "$A_CALL_LOG" "login"

# --- Scenario: a missing `jq` dependency must fail fast ----------------------
# The script parses every `bw` response with jq, so a missing jq should abort
# with an actionable message *before* any filesystem or vault work — not crash
# cryptically partway through. PATH carries `bw` (and `dirname`, needed to
# resolve the script's own dir) but deliberately omits `jq`.
echo ""
echo "sync_secrets.sh — missing jq must fail fast before touching anything:"

T4_BIN="$WORK/bin_nojq"
mkdir -p "$T4_BIN"
cp "$STUB_BIN/bw" "$T4_BIN/bw"
chmod +x "$T4_BIN/bw"
ln -s "$(command -v dirname)" "$T4_BIN/dirname"

T4_SECRETS="$WORK/secrets_nojq"
mkdir -p "$T4_SECRETS"
printf 'value\n' >"$T4_SECRETS/token.env"

T4_OUTPUT_FILE="$WORK/t4.log"
set +e
SECRETS_DIR="$T4_SECRETS" BW_SESSION="" PATH="$T4_BIN" \
	"$BASH_BIN" "$SCRIPT_UNDER_TEST" upload </dev/null >"$T4_OUTPUT_FILE" 2>&1
T4_EXIT=$?
set -e 2>/dev/null || true
T4_OUTPUT="$(cat "$T4_OUTPUT_FILE")"

assert_nonzero_exit "upload fails when jq is missing" "$T4_EXIT"
assert_output_contains "names the missing jq dependency" "$T4_OUTPUT" "jq"
assert_no_plaintext_tarball "no tarball is created when a dependency is missing" "$T4_SECRETS"

# --- Shared stub: an already-unlocked vault that accepts an upload -----------
# Reports the vault as unlocked (a valid inherited BW_SESSION) and returns an
# already-existing item so the happy path runs end to end. Every bw subcommand
# is appended to $BW_CALL_LOG so a scenario can assert that login/unlock/lock
# were never issued.
SUCCESS_BIN="$WORK/bin_success"
mkdir -p "$SUCCESS_BIN"
cat >"$SUCCESS_BIN/bw" <<'STUB'
#!/usr/bin/env bash
[[ -n "${BW_CALL_LOG:-}" ]] && printf '%s\n' "$*" >>"$BW_CALL_LOG"
case "$1" in
status)
	echo '{"serverUrl":null,"lastSync":"now","userEmail":"test@example.com","status":"unlocked"}'
	;;
sync) ;;
get)
	case "$2" in
	item) echo '{"id":"item-123","name":"dotfiles-secrets","attachments":[]}' ;;
	template) echo '{"name":"","notes":"","type":1,"secureNote":{"type":0}}' ;;
	esac
	;;
encode) base64 ;;
*) ;;
esac
exit 0
STUB
chmod +x "$SUCCESS_BIN/bw"

# --- Scenario: an inherited, unlocked session uploads without auth calls -----
echo ""
echo "sync_secrets.sh upload — uses an inherited session, never logs in/out:"
T3_SECRETS="$WORK/secrets_inherited"
mkdir -p "$T3_SECRETS"
printf 'token\n' >"$T3_SECRETS/token.env"
T3_CALL_LOG="$WORK/t3_calls.log"
: >"$T3_CALL_LOG"
T3_OUTPUT_FILE="$WORK/t3.log"
set +e
SECRETS_DIR="$T3_SECRETS" BW_SESSION="inherited-session" \
	BW_CALL_LOG="$T3_CALL_LOG" PATH="$SUCCESS_BIN:$PATH" \
	"$BASH_BIN" "$SCRIPT_UNDER_TEST" upload </dev/null >"$T3_OUTPUT_FILE" 2>&1
T3_EXIT=$?
set -e 2>/dev/null || true
assert_zero_exit "upload succeeds using the inherited session" "$T3_EXIT"
assert_bw_subcommand_not_called "never logs in" "$T3_CALL_LOG" "login"
assert_bw_subcommand_not_called "never unlocks" "$T3_CALL_LOG" "unlock"
assert_bw_subcommand_not_called "never locks the inherited session" "$T3_CALL_LOG" "lock"

# --- Summary -----------------------------------------------------------------
echo ""
echo "Passed: $PASS  Failed: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
