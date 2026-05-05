#!/bin/zsh

[[ -z $ZELLIJ ]] && exit 0

words=(
	aurora blaze cedar coral drift ember falcon glacier harbor iris
	jade karma lotus maple nebula opal prism quartz ripple sage
	thunder umbra velvet whisper xenon yarrow zenith arctic breeze
	canyon delta echo flint grove helix indigo jasper kelp lunar
	meadow nova orbit pine reef solar tidal unity vertex wren
)

word_count=${#words[@]}
random_index=$(( RANDOM % word_count + 1 ))
tab_name="${words[$random_index]}"

tab_index=$(zellij action dump-layout 2>/dev/null | awk '/^[[:space:]]*tab[[:space:]]/ {count++; if (/focus=true/) {print count; exit}}')
[[ -n $tab_index ]] && tab_name="${tab_index}.${tab_name}"

zellij action rename-tab "$tab_name" 2>/dev/null
