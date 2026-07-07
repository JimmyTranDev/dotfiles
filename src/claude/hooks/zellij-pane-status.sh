#!/bin/bash
#
# zellij-pane-status.sh — Claude Code / storecode hook that mirrors the running
# session's status in the title of the zellij pane it lives in, matching the
# opencode zellij-pane-status plugin's emoji vocabulary (🛠️ working, ✅ idle,
# ⏸️ needs input).
#
# Tracked at src/claude/hooks/zellij-pane-status.sh and reached via the
# ~/.claude -> src/claude symlink. Edit this file directly.
#
# Claude/storecode hooks are stateless shell invocations, so the desired status
# is passed as the first ARGUMENT. Wired from settings.json as
# `command "<this> <state>"`:
#   SessionStart, Stop            -> idle          (✅ ready / turn ended)
#   UserPromptSubmit, PreToolUse  -> working       (🛠️ turn in progress; PreToolUse
#                                                    also recovers ⏸️ -> 🛠️ once a
#                                                    permission prompt is approved)
#   Notification                  -> needs-input   (⏸️ — but see below)
#
# The `needs-input` arg is REFINED by the event JSON, because Claude's
# Notification event covers several notification_type values, not just permission
# prompts. A single "Stop -> idle" is otherwise clobbered back to ⏸️ by the
# idle_prompt notification Claude fires right after a turn ends ("done, waiting
# for your next prompt"), leaving a *finished* session stuck showing needs-input.
# So for the `needs-input` arg we read notification_type from stdin and keep ⏸️
# ONLY for types that genuinely await the user; the "done/idle" types collapse to
# ✅ idle so the terminal state stays solid:
#   permission_prompt, elicitation_dialog, agent_needs_input -> needs-input (⏸️)
#   idle_prompt, agent_completed, auth_success, (unknown)    -> idle        (✅)
#
# Each Claude/storecode process renames only its own pane via $ZELLIJ_PANE_ID
# (inherited from the pane's env), so this stays correct in layouts with several
# tool panes. No-op outside zellij.
#
# Two hard rules, both load-bearing:
#   1. ALWAYS exit 0 — a non-zero PreToolUse hook can BLOCK the tool call.
#   2. Print NOTHING to stdout — a SessionStart/UserPromptSubmit hook's stdout is
#      injected into the model's context. Every side effect is silenced.

# Read the event JSON off stdin (draining it also stops Claude seeing a broken
# pipe). Only the `needs-input` arg consults it; the other states come from $1.
event_json="$(cat 2>/dev/null || true)"

state="$1"

# Extract a JSON string field's value without a JSON parser dependency: match
# "field"…:…"value" and print the value. Returns empty if absent/not a string.
json_string_field() {
	local field="$1" json="$2"
	printf '%s' "$json" |
		sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
		head -n1
}

# For a Notification (state=needs-input), Claude sends notification_type telling
# us whether the user is actually needed. Downgrade the "done/idle/informational"
# types to idle so a finished turn doesn't linger on ⏸️.
if [[ "$state" == "needs-input" ]]; then
	notification_type="$(json_string_field notification_type "$event_json")"
	case "$notification_type" in
	permission_prompt | elicitation_dialog | agent_needs_input)
		state="needs-input"
		;;
	idle_prompt | agent_completed | auth_success | elicitation_complete | elicitation_response)
		state="idle"
		;;
	"")
		# Empty stdin or unparseable JSON (e.g. invoked manually): keep the
		# caller's intent so behavior can't regress below the old code, where
		# every Notification meant needs-input.
		state="needs-input"
		;;
	*)
		# An unrecognized future type: treat as idle rather than falsely
		# claiming the user is blocked.
		state="idle"
		;;
	esac
fi

# No-op when not running inside a zellij pane.
if [[ -z "$ZELLIJ" || -z "$ZELLIJ_PANE_ID" ]]; then
	exit 0
fi

emoji=""
label=""
case "$state" in
working) emoji="🛠️" label="working" ;;
idle) emoji="✅" label="idle" ;;
needs-input) emoji="⏸️" label="needs input" ;;
*) exit 0 ;;
esac

# Title: the session directory's basename (opencode falls back to the same),
# with $HOME shown as "~" and trimmed to 24 chars to match the opencode plugin.
title="${PWD##*/}"
[[ "$PWD" == "$HOME" ]] && title="~"
if ((${#title} > 24)); then
	title="${title:0:23}…"
fi

name="${emoji} ${label}"
[[ -n "$title" ]] && name="${name} · ${title}"

zellij action rename-pane --pane-id "$ZELLIJ_PANE_ID" "$name" >/dev/null 2>&1 || true

exit 0
