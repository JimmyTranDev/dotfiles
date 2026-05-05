#!/bin/zsh

[[ -z $ZELLIJ ]] && exit 0

folder_name="${PWD##*/}"
tab_name="${folder_name:0:8}"

tab_index=$(zellij action dump-layout 2>/dev/null | awk '/^[[:space:]]*tab[[:space:]]/ {count++; if (/focus=true/) {print count; exit}}')
[[ -n $tab_index ]] && tab_name="${tab_index}.${tab_name}"

zellij action rename-tab "$tab_name" 2>/dev/null
