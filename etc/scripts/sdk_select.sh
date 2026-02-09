#!/bin/bash

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
SDKMAN_INIT="$SDKMAN_DIR/bin/sdkman-init.sh"

if [[ ! -f "$SDKMAN_INIT" ]]; then
	echo "SDKMAN not found"
	exit 1
fi

source "$SDKMAN_INIT"

candidate="${1:-java}"
candidate_dir="$SDKMAN_DIR/candidates/$candidate"

if [[ ! -d "$candidate_dir" ]]; then
	echo "No $candidate versions installed"
	exit 1
fi

versions=()
current=""
if [[ -L "$candidate_dir/current" ]]; then
	current=$(basename "$(readlink "$candidate_dir/current")")
fi

for dir in "$candidate_dir"/*/; do
	[[ -d "$dir" ]] || continue
	version=$(basename "$dir")
	[[ "$version" == "current" ]] && continue
	versions+=("$version")
done

if [[ ${#versions[@]} -eq 0 ]]; then
	echo "No $candidate versions installed"
	exit 1
fi

IFS=$'\n' sorted=($(printf "%s\n" "${versions[@]}" | sort -rV))
unset IFS

display=()
for v in "${sorted[@]}"; do
	if [[ "$v" == "$current" ]]; then
		display+=("$v *")
	else
		display+=("$v")
	fi
done

selected=$(printf "%s\n" "${display[@]}" | fzf --prompt="Select $candidate version: ")
[[ -z "$selected" ]] && exit 0

selected="${selected% \*}"
sdk use "$candidate" "$selected"
