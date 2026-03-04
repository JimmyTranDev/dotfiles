#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

EMOJI_SUCCESS="✓"
EMOJI_ERROR="❌"
EMOJI_WARNING="⚠️"
EMOJI_INFO="ℹ️"
EMOJI_ROCKET="🚀"
EMOJI_LINK="🔗"
EMOJI_TRASH="🗑"
EMOJI_EYE="👁"
EMOJI_CLOUD="☁️"

log_info() {
	echo -e "${CYAN}${EMOJI_INFO} $1${NC}"
}

log_success() {
	echo -e "${GREEN}${EMOJI_SUCCESS} $1${NC}"
}

log_error() {
	echo -e "${RED}${EMOJI_ERROR} $1${NC}"
}

log_warning() {
	echo -e "${YELLOW}${EMOJI_WARNING} $1${NC}"
}

log_header() {
	local emoji="${2:-$EMOJI_ROCKET}"
	echo -e "${BLUE}${emoji} $1${NC}"
}
