#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"

main() {
	if [[ -z "$1" ]]; then
		echo "Usage: $0 <port>"
		exit 1
	fi

	local port="$1"

	if ! [[ "$port" =~ ^[0-9]+$ ]]; then
		log_error "'$port' is not a valid port number"
		exit 1
	fi

	local pids
	pids=$(lsof -ti "tcp:$port" 2>/dev/null || true)

	if [[ -z "$pids" ]]; then
		log_info "No process found on port $port"
	else
		local pid_count
		pid_count=$(echo "$pids" | wc -l | tr -d ' ')
		if [[ "$pid_count" -gt 1 ]]; then
			log_warning "Found $pid_count processes on port $port"
		fi
		log_info "Killing process(es) on port $port: $(echo "$pids" | tr '\n' ' ')"
		echo "$pids" | xargs kill 2>/dev/null
		sleep 1
		local remaining
		remaining=$(lsof -ti "tcp:$port" 2>/dev/null || true)
		if [[ -n "$remaining" ]]; then
			log_warning "Processes still alive, sending SIGKILL..."
			echo "$remaining" | xargs kill -9 2>/dev/null
		fi
	fi
}

main "$@"
