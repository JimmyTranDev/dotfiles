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
# is passed as the first ARGUMENT rather than parsed from the event JSON. Wired
# from settings.json as `command "<this> <state>"`:
#   SessionStart, Stop            -> idle          (✅ ready / turn ended)
#   UserPromptSubmit, PreToolUse  -> working       (🛠️ turn in progress; PreToolUse
#                                                    also recovers ⏸️ -> 🛠️ once a
#                                                    permission prompt is approved)
#   Notification                  -> needs-input   (⏸️ permission / idle-waiting)
#
# Each Claude/storecode process renames only its own pane via $ZELLIJ_PANE_ID
# (inherited from the pane's env), so this stays correct in layouts with several
# tool panes. No-op outside zellij.
#
# Two hard rules, both load-bearing:
#   1. ALWAYS exit 0 — a non-zero PreToolUse hook can BLOCK the tool call.
#   2. Print NOTHING to stdout — a SessionStart/UserPromptSubmit hook's stdout is
#      injected into the model's context. Every side effect is silenced.

# Drain the event JSON on stdin so Claude never sees a broken pipe; nothing in it
# is needed (state comes from $1, the title from $PWD).
cat >/dev/null 2>&1 || true

state="$1"

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
