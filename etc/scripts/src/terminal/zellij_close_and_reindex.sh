#!/bin/zsh

[[ -z $ZELLIJ ]] && exit 0

zellij action close-tab

sleep 0.1

"$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/terminal/zellij_update_tab_indexes.sh"
