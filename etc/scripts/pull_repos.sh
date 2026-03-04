#!/bin/zsh

TARGET_DIR="${1:-.}"

if [[ ! -d "$TARGET_DIR" ]]; then
	echo "Error: '$TARGET_DIR' is not a directory."
	exit 1
fi

echo "Fetching all folders inside: $TARGET_DIR"

for dir in "$TARGET_DIR"/*/; do
	if [[ -d "$dir" ]]; then
		if [[ ! -d "$dir/.git" && ! -f "$dir/.git" ]]; then
			echo "Skipping non-git directory: $dir"
			continue
		fi
		echo "Pulling: $dir"
		git -C "$dir" pull --rebase || {
			echo "Failed to pull changes in $dir"
			continue
		}
	fi
done
