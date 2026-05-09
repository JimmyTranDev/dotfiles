#!/bin/bash

[[ -n "${_CONSTS_COLORS_LOADED:-}" ]] && return 0
_CONSTS_COLORS_LOADED=1

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
