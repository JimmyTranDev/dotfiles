#!/bin/zsh

[[ -z $ZELLIJ ]] && exit 0

current_dir="${PWD##*/}"
[[ "$PWD" == "$HOME" ]] && current_dir="~"
max_length="${ZELLIJ_TAB_NAME_MAX_LENGTH:-20}"
tab_name="${current_dir:0:$max_length}"

tab_index=$(zellij action dump-layout 2>/dev/null | awk '/^[[:space:]]*tab[[:space:]]/ {count++; if (/focus=true/) {print count; exit}}')
[[ -n $tab_index ]] && tab_name="${tab_index}. ${tab_name}"

zellij action rename-tab "$tab_name" 2>/dev/null
