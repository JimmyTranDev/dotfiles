#!/bin/zsh

[[ -z $ZELLIJ ]] && exit 0

layout=$(zellij action dump-layout 2>/dev/null)
[[ -z $layout ]] && exit 0

current_tab_name=$(echo "$layout" | awk '/^[[:space:]]*tab[[:space:]].*focus=true/ {match($0, /name="[^"]*"/); print substr($0, RSTART+6, RLENGTH-7); exit}')
[[ -z $current_tab_name ]] && exit 0
current_tab_base=$(echo "$current_tab_name" | sed 's/^[0-9][0-9]*\.//')

tab_lines=$(echo "$layout" | awk '/^[[:space:]]*tab[[:space:]]/ {print NR": "$0}')
tab_count=$(echo "$tab_lines" | wc -l | tr -d ' ')
[[ $tab_count -eq 0 ]] && exit 0

needs_update=false
idx=0
while IFS= read -r line; do
	line_num=$(echo "$line" | cut -d':' -f1)
	tab_line=$(echo "$line" | cut -d':' -f2-)
	current_name=$(echo "$tab_line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')

	base_name=$(echo "$current_name" | sed 's/^[0-9][0-9]*\.//')
	base_name=$(echo "$base_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	[[ -z $base_name ]] && base_name=$current_name

	if [[ -z $base_name ]] || [[ $base_name =~ ^[0-9]+\.?[[:space:]]*$ ]] || [[ $base_name =~ ^Tab\ #[0-9]+$ ]]; then
		continue
	fi

	((idx++))
	expected_name="${idx}.${base_name}"

	if [[ $current_name != $expected_name ]]; then
		needs_update=true
		break
	fi
done <<<"$tab_lines"

[[ $needs_update == false ]] && exit 0

idx=0
tab_pos=0
while IFS= read -r line; do
	((tab_pos++))
	line_num=$(echo "$line" | cut -d':' -f1)
	tab_line=$(echo "$line" | cut -d':' -f2-)
	current_name=$(echo "$tab_line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')

	base_name=$(echo "$current_name" | sed 's/^[0-9][0-9]*\.//')
	base_name=$(echo "$base_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	[[ -z $base_name ]] && base_name=$current_name

	if [[ -z $base_name ]] || [[ $base_name =~ ^[0-9]+\.?[[:space:]]*$ ]] || [[ $base_name =~ ^Tab\ #[0-9]+$ ]]; then
		continue
	fi

	((idx++))
	new_name="${idx}.${base_name}"

	if [[ $current_name != $new_name ]]; then
		zellij action go-to-tab $tab_pos 2>/dev/null
		sleep 0.03
		zellij action rename-tab "$new_name" 2>/dev/null
	fi
done <<<"$tab_lines"

target_idx=1
tab_idx=0
while IFS= read -r line; do
	((tab_idx++))
	tab_line=$(echo "$line" | cut -d':' -f2-)
	name=$(echo "$tab_line" | sed -n 's/.*name="\([^"]*\)".*/\1/p')
	base=$(echo "$name" | sed 's/^[0-9][0-9]*\.//')
	[[ $base == $current_tab_base ]] && target_idx=$tab_idx && break
done <<<"$tab_lines"
zellij action go-to-tab $target_idx 2>/dev/null
