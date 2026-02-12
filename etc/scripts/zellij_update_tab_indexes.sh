#!/bin/zsh

[[ -z $ZELLIJ ]] && exit 0

layout=$(zellij action dump-layout 2>/dev/null)
[[ -z $layout ]] && exit 0

current_tab=$(echo "$layout" | awk '/^[[:space:]]*tab[[:space:]]/ {count++; if (/focus=true/) {print count; exit}}')
[[ -z $current_tab ]] && exit 0

tab_lines=$(echo "$layout" | awk '/^[[:space:]]*tab[[:space:]]/ {print NR": "$0}')
tab_count=$(echo "$tab_lines" | wc -l | tr -d ' ')
[[ $tab_count -eq 0 ]] && exit 0

needs_update=false
while IFS= read -r line; do
	idx=$(echo "$line" | cut -d':' -f1)
	tab_line=$(echo "$line" | cut -d':' -f2-)
	current_name=$(echo "$tab_line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')

	base_name=$(echo "$current_name" | sed 's/^[0-9]*\. //')
	[[ -z $base_name ]] && base_name=$current_name

	tab_idx=$(echo "$tab_lines" | grep -n "^${idx}:" | cut -d':' -f1)
	expected_prefix="${tab_idx}. "

	if [[ $current_name != "${expected_prefix}${base_name}" ]]; then
		needs_update=true
		break
	fi
done <<<"$tab_lines"

[[ $needs_update == false ]] && exit 0

idx=0
while IFS= read -r line; do
	((idx++))
	line_num=$(echo "$line" | cut -d':' -f1)
	tab_line=$(echo "$line" | cut -d':' -f2-)
	current_name=$(echo "$tab_line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')

	base_name=$(echo "$current_name" | sed 's/^[0-9]*\. //')
	[[ -z $base_name ]] && base_name=$current_name

	new_name="${idx}. ${base_name}"

	if [[ $current_name != $new_name ]]; then
		zellij action go-to-tab $idx 2>/dev/null
		sleep 0.03
		zellij action rename-tab "$new_name" 2>/dev/null
	fi
done <<<"$tab_lines"

zellij action go-to-tab $current_tab 2>/dev/null
