#!/bin/bash

_LOGGING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LOGGING_DIR/../consts/colors.sh"
source "$_LOGGING_DIR/../consts/emoji.sh"

log_info() {
	echo -e "${CYAN}${EMOJI_INFO} $1${NC}" >&2
}

log_success() {
	echo -e "${GREEN}${EMOJI_SUCCESS} $1${NC}" >&2
}

log_error() {
	echo -e "${RED}${EMOJI_ERROR} $1${NC}" >&2
}

log_warning() {
	echo -e "${YELLOW}${EMOJI_WARNING} $1${NC}" >&2
}

log_header() {
	local emoji="${2:-$EMOJI_ROCKET}"
	echo -e "${BLUE}${emoji} $1${NC}" >&2
}
