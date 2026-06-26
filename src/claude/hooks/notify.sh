#!/bin/bash
#
# claude-notify.sh — Claude Code hook runtime for sound + desktop notifications.
#
# Tracked directly at src/claude/hooks/notify.sh and reached via the
# ~/.claude -> src/claude symlink. Edit this file directly.
#
# Claude hooks are stateless shell invocations, so a rich notification body
# (elapsed time, tool counts, changed files) is reconstructed from a small
# per-session state file.
#
# Wired from settings.json hooks:
#   - PostToolUse -> accumulate tool count / last tool / changed files
#   - Stop        -> "Task completed": elapsed + counts, then clear state
#   - Notification-> "Waiting for input": permission prompt
#
# Reads one hook-event JSON object on stdin. Must ALWAYS exit 0 so a failure
# here never blocks the agent loop.
#
# Security: state lives in a per-user 0700 directory whose ownership is verified
# before use (the parent ${TMPDIR:-/tmp} may be world-writable on Linux). State
# is never `source`d — it is parsed with a fixed key allowlist and every numeric
# value is validated before use in arithmetic, so a tampered/planted file can
# never inject code.

# Intentionally no `set -e`: every external call is wrapped and the script must
# exit 0 regardless of individual command failures.

readonly TITLE="Claude Code"
readonly IDLE_SOUND="${CLAUDE_SOUND_IDLE:-Glass}"
readonly PERMISSION_SOUND="${CLAUDE_SOUND_PERMISSION:-Ping}"
readonly VOLUME="${CLAUDE_SOUND_VOLUME:-0.3}"

# Populated by init_state_dir; empty means "degrade to stateless".
STATE_DIR=""
# Populated by read_state.
TASK_START=""
TOOL_COUNT=0
LAST_TOOL=""

format_duration() {
	local ms="$1"
	local seconds=$((ms / 1000))
	if ((seconds < 60)); then
		printf '%ss' "$seconds"
		return
	fi
	local minutes=$((seconds / 60))
	local rem_seconds=$((seconds % 60))
	if ((minutes < 60)); then
		if ((rem_seconds > 0)); then
			printf '%sm %ss' "$minutes" "$rem_seconds"
		else
			printf '%sm' "$minutes"
		fi
		return
	fi
	local hours=$((minutes / 60))
	local rem_minutes=$((minutes % 60))
	if ((rem_minutes > 0)); then
		printf '%sh %sm' "$hours" "$rem_minutes"
	else
		printf '%sh' "$hours"
	fi
}

get_session_name() {
	local cwd="$1"
	if [[ -n "$cwd" ]]; then
		printf '%s' "${cwd##*/}"
		return
	fi
	printf 'Claude Code'
}

# Current wall-clock in milliseconds. macOS `date` lacks %3N, so fall back to
# seconds * 1000 when the nanosecond format is unsupported.
now_ms() {
	local ms
	ms="$(date +%s%3N 2>/dev/null)"
	if [[ "$ms" =~ ^[0-9]+$ ]]; then
		printf '%s' "$ms"
		return
	fi
	printf '%s' "$(($(date +%s) * 1000))"
}

# Create (once) a per-user state directory under TMPDIR and verify we own it and
# it is a real directory (not a symlink an attacker pre-planted in world-writable
# /tmp). On any failure, leave STATE_DIR empty so the caller degrades to a
# stateless notification rather than touching an untrusted path.
init_state_dir() {
	local base="${TMPDIR:-/tmp}"
	local uid
	uid="$(id -u 2>/dev/null)"
	if [[ -z "$uid" ]]; then
		return
	fi
	local dir="${base%/}/claude-notify-${uid}"
	mkdir -p "$dir" 2>/dev/null || true
	chmod 700 "$dir" 2>/dev/null || true
	if [[ -L "$dir" || ! -d "$dir" ]]; then
		return
	fi
	local owner
	owner="$(stat -f '%u' "$dir" 2>/dev/null || stat -c '%u' "$dir" 2>/dev/null)"
	if [[ "$owner" != "$uid" ]]; then
		return
	fi
	STATE_DIR="$dir"
}

# Parse a state file with a fixed key allowlist. Never sources the file, so a
# tampered file cannot execute code; numeric fields are validated and anything
# unexpected is ignored.
read_state() {
	local file="$1"
	TASK_START=""
	TOOL_COUNT=0
	LAST_TOOL=""
	if [[ ! -f "$file" || -L "$file" ]]; then
		return
	fi
	local key value
	while IFS='=' read -r key value; do
		case "$key" in
		TASK_START)
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				TASK_START="$value"
			fi
			;;
		TOOL_COUNT)
			if [[ "$value" =~ ^[0-9]+$ ]]; then
				TOOL_COUNT="$value"
			fi
			;;
		LAST_TOOL)
			LAST_TOOL="$value"
			;;
		esac
	done <"$file"
}

play_sound() {
	local sound="$1"
	if [[ "$(uname)" == "Darwin" ]]; then
		afplay -v "$VOLUME" "/System/Library/Sounds/${sound}.aiff" >/dev/null 2>&1 &
	elif [[ "$(uname)" == "Linux" ]]; then
		paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 &
	fi
}

send_notification() {
	local subtitle="$1"
	local body="$2"
	if [[ "$(uname)" == "Darwin" ]]; then
		# Escape backslashes first, then double quotes, so the value cannot break
		# out of the AppleScript string literal.
		local escaped="${body//\\/\\\\}"
		escaped="${escaped//\"/\\\"}"
		osascript -e "display notification \"$escaped\" with title \"$TITLE\" subtitle \"$subtitle\"" >/dev/null 2>&1 || true
	elif [[ "$(uname)" == "Linux" ]]; then
		notify-send "$TITLE" "$subtitle: $body" >/dev/null 2>&1 || true
	fi
}

# Drop per-session state files left behind by crashed/cancelled sessions. Only
# called from the Stop branch (not the PostToolUse hot path) to keep tool calls
# fast. Operates inside our own private dir, so it only ever removes our files.
cleanup_stale_state() {
	if [[ -z "$STATE_DIR" ]]; then
		return
	fi
	find "$STATE_DIR" -maxdepth 1 -type f -mtime +1 -delete 2>/dev/null || true
}

handle_post_tool_use() {
	local state_file="$1"
	local files_file="$2"
	local tool="$3"
	local file="$4"
	read_state "$state_file"
	if [[ -z "$TASK_START" ]]; then
		TASK_START="$(now_ms)"
	fi
	TOOL_COUNT=$((TOOL_COUNT + 1))
	# Sanitize the tool name to a safe charset: it originates from untrusted hook
	# JSON and is later rendered into a notification.
	local safe_tool="${tool//[^A-Za-z0-9_-]/_}"
	if [[ -n "$safe_tool" ]]; then
		LAST_TOOL="$safe_tool"
	fi
	{
		printf 'TASK_START=%s\n' "$TASK_START"
		printf 'TOOL_COUNT=%s\n' "$TOOL_COUNT"
		printf 'LAST_TOOL=%s\n' "$LAST_TOOL"
	} >"$state_file" 2>/dev/null
	# Track changed files (deduped) for Edit/Write/NotebookEdit.
	if [[ -n "$file" && ("$tool" == "Edit" || "$tool" == "Write" || "$tool" == "NotebookEdit") ]]; then
		if [[ ! -f "$files_file" ]] || ! grep -qxF "$file" "$files_file" 2>/dev/null; then
			printf '%s\n' "$file" >>"$files_file" 2>/dev/null
		fi
	fi
}

handle_stop() {
	local state_file="$1"
	local files_file="$2"
	local cwd="$3"
	local project
	project="$(get_session_name "$cwd")"
	local body="$project"

	read_state "$state_file"
	if [[ -n "$TASK_START" ]]; then
		body="${project} - $(format_duration $(($(now_ms) - TASK_START)))"
	fi

	local context_parts=()
	if [[ -n "$LAST_TOOL" ]]; then
		context_parts+=("Last: $LAST_TOOL")
	fi
	if [[ "$TOOL_COUNT" -gt 0 ]]; then
		context_parts+=("${TOOL_COUNT} calls")
	fi
	local file_count=0
	if [[ -f "$files_file" ]]; then
		file_count="$(wc -l <"$files_file" 2>/dev/null | tr -d ' ')"
		if [[ ! "$file_count" =~ ^[0-9]+$ ]]; then
			file_count=0
		fi
	fi
	if [[ "$file_count" -gt 0 ]]; then
		local plural="file"
		if [[ "$file_count" -gt 1 ]]; then
			plural="files"
		fi
		context_parts+=("${file_count} ${plural}")
	fi
	if [[ "${#context_parts[@]}" -gt 0 ]]; then
		# Join with " | " manually: a multi-char IFS only joins on its first char,
		# so "${arr[*]}" with IFS=" | " would collapse to single spaces.
		local joined="${context_parts[0]}"
		local i
		for ((i = 1; i < ${#context_parts[@]}; i++)); do
			joined="${joined} | ${context_parts[$i]}"
		done
		body="${body}"$'\n'"${joined}"
	fi

	play_sound "$IDLE_SOUND"
	send_notification "Task completed" "$body"
	rm -f "$state_file" "$files_file" 2>/dev/null || true
	cleanup_stale_state
}

handle_notification() {
	local cwd="$1"
	local body
	body="$(get_session_name "$cwd")"
	play_sound "$PERMISSION_SOUND"
	send_notification "Waiting for input" "$body"
}

main() {
	local input
	input="$(cat)"

	# Parse the hook payload with node (already a hard dependency of the
	# converter). Five fields, one per line, in a fixed order. Degrade to empty
	# fields if node is missing or the JSON is malformed.
	local parsed=""
	if command -v node &>/dev/null; then
		parsed="$(printf '%s' "$input" | node -e '
			let d = "";
			process.stdin.on("data", (c) => { d += c; });
			process.stdin.on("end", () => {
				let j = {};
				try { j = JSON.parse(d); } catch (e) { j = {}; }
				const filePath = (j.tool_input && j.tool_input.file_path) || "";
				const out = [
					j.hook_event_name || "",
					j.session_id || "",
					j.cwd || "",
					j.tool_name || "",
					filePath,
				];
				process.stdout.write(out.join("\n"));
			});
		' 2>/dev/null)"
	fi

	local event session cwd tool file
	{
		IFS= read -r event
		IFS= read -r session
		IFS= read -r cwd
		IFS= read -r tool
		IFS= read -r file
	} <<EOF
$parsed
EOF

	if [[ -z "$session" ]]; then
		session="default"
	fi
	# Sanitize the session id for use in a filename.
	session="${session//[^A-Za-z0-9_-]/_}"

	init_state_dir

	# Without a trusted state dir, degrade to a stateless notification: still
	# play the sound and notify, just without the rich accumulated body.
	if [[ -z "$STATE_DIR" ]]; then
		case "$event" in
		Stop)
			play_sound "$IDLE_SOUND"
			send_notification "Task completed" "$(get_session_name "$cwd")"
			;;
		Notification)
			handle_notification "$cwd"
			;;
		esac
		exit 0
	fi

	local state_file="${STATE_DIR}/${session}.state"
	local files_file="${STATE_DIR}/${session}.files"

	case "$event" in
	PostToolUse)
		handle_post_tool_use "$state_file" "$files_file" "$tool" "$file"
		;;
	Stop)
		handle_stop "$state_file" "$files_file" "$cwd"
		;;
	Notification)
		handle_notification "$cwd"
		;;
	esac

	exit 0
}

main "$@"
