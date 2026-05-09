#!/bin/bash

[[ -n "${_CONSTS_DIRS_LOADED:-}" ]] && return 0
_CONSTS_DIRS_LOADED=1

PROGRAMMING_EXCLUDED_DIRS=("Worktrees" "wcreated" "wcheckout" "secrets")
