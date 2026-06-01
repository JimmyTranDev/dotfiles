#!/bin/bash

[[ -n "${_UTILS_COMMON_LOADED:-}" ]] && return 0
_UTILS_COMMON_LOADED=1

_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$_COMMON_DIR/logging.sh"
source "$_COMMON_DIR/json.sh"
source "$_COMMON_DIR/detect.sh"
source "$_COMMON_DIR/git.sh"
source "$_COMMON_DIR/utility.sh"
