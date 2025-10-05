#!/bin/zsh
# Auto-start Zellij for Ghostty
# This script ensures Zellij loads properly when Ghostty starts

# Check if we should start Zellij
if [[ -z "$ZELLIJ" ]] && [[ -z "$TMUX" ]] && command -v zellij >/dev/null 2>&1; then
    # We're not already in a multiplexer and Zellij is available
    
    # Try to attach to existing session, or create new one
    if zellij list-sessions 2>/dev/null | grep -q .; then
        # There are existing sessions
        echo "Attaching to existing Zellij session..."
        exec zellij attach
    else
        # No existing sessions, create new one
        echo "Starting new Zellij session..."
        exec zellij
    fi
else
    # Start regular shell
    exec zsh
fi
