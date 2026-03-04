#!/bin/zsh

PROGRAMMING_DIR="${PROGRAMMING_DIR:-$HOME/Programming}"
WORK_DIR="${WORK_DIR:-$PROGRAMMING_DIR/work}"
PERSONAL_DIR="${PERSONAL_DIR:-$PROGRAMMING_DIR/personal}"

pull_dir() {
	local target_dir="$1"
	local label="$2"

	if [[ ! -d "$target_dir" ]]; then
		echo "Skipping $label: $target_dir does not exist"
		return
	fi

	echo "=== Pulling $label repos: $target_dir ==="

	for dir in "$target_dir"/*/; do
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
}

pull_dir "$WORK_DIR" "work"
pull_dir "$PERSONAL_DIR" "personal"
