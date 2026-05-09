#!/bin/zsh

if [[ -z "$1" ]]; then
	echo "Usage: $0 <port>"
	exit 1
fi

PORT="$1"

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
	echo "Error: '$PORT' is not a valid port number"
	exit 1
fi

PIDS=$(lsof -ti "tcp:$PORT")

if [[ -z "$PIDS" ]]; then
	echo "No process found on port $PORT"
else
	pid_count=$(echo "$PIDS" | wc -l | tr -d ' ')
	if [[ "$pid_count" -gt 1 ]]; then
		echo "Warning: Found $pid_count processes on port $PORT"
	fi
	echo "Killing process(es) on port $PORT: $(echo $PIDS | tr '\n' ' ')"
	echo "$PIDS" | xargs kill 2>/dev/null
	sleep 1
	remaining=$(lsof -ti "tcp:$PORT" 2>/dev/null)
	if [[ -n "$remaining" ]]; then
		echo "Processes still alive, sending SIGKILL..."
		echo "$remaining" | xargs kill -9 2>/dev/null
	fi
fi
