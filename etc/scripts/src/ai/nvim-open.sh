#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

DESCRIPTION="Open files in an existing nvim instance or start a new one"

show_help() {
	echo "Usage: nvim-open.sh [options] <file...>"
	echo ""
	echo "${DESCRIPTION}"
	echo ""
	echo "Options:"
	echo "  --help    Show this help message"
	echo ""
	echo "Behavior:"
	echo "  1. If NVIM env var is set (inside nvim terminal), opens in parent nvim"
	echo "  2. If a nvim server socket is found, opens in that instance"
	echo "  3. Otherwise, opens a new nvim instance"
}

find_nvim_socket() {
	local socket_dir="${XDG_RUNTIME_DIR:-/tmp}"
	local socket=""

	for candidate in "${socket_dir}"/nvim.*.0 "${socket_dir}"/nvimsocket /tmp/nvim.sock; do
		if [ -S "${candidate}" ]; then
			socket="${candidate}"
			break
		fi
	done

	if [ -z "${socket}" ]; then
		local found
		found=$(find /tmp -maxdepth 2 -name "nvim.*.0" -type s 2>/dev/null | head -1)
		if [ -n "${found}" ]; then
			socket="${found}"
		fi
	fi

	echo "${socket}"
}

main() {
	if [ "$1" = "--help" ]; then
		show_help
		exit 0
	fi

	if [ $# -eq 0 ]; then
		log_error "No files specified"
		show_help
		exit 1
	fi

	local files_json=""
	for file in "$@"; do
		local resolved
		resolved=$(realpath "${file}" 2>/dev/null || echo "${file}")
		local escaped
		escaped=$(json_escape "$resolved")
		if [[ -n "$files_json" ]]; then
			files_json="${files_json},${escaped}"
		else
			files_json="$escaped"
		fi
	done

	local mode=""

	if [ -n "${NVIM}" ]; then
		mode="parent"
		log_info "Opening in parent nvim instance"
		for file in "$@"; do
			nvim --server "${NVIM}" --remote "$(realpath "${file}")"
		done
		json_output $(json_obj_raw \
			"opened" "true" \
			"files" "[${files_json}]" \
			"mode" "$(json_escape "$mode")")
		return
	fi

	local socket
	socket=$(find_nvim_socket)

	if [ -n "${socket}" ]; then
		mode="socket"
		log_info "Opening in existing nvim (${socket})"
		for file in "$@"; do
			nvim --server "${socket}" --remote "$(realpath "${file}")"
		done
		json_output $(json_obj_raw \
			"opened" "true" \
			"files" "[${files_json}]" \
			"mode" "$(json_escape "$mode")")
		return
	fi

	mode="new"
	log_info "No running nvim found, starting new instance"
	nvim "$@"
	json_output $(json_obj_raw \
		"opened" "true" \
		"files" "[${files_json}]" \
		"mode" "$(json_escape "$mode")")
}

main "$@"
