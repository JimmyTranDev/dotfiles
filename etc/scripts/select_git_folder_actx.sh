#!/bin/bash

# Script to select a git folder or worktree from ~/Programming and create a symlink with -actx suffix
# Supports both regular git repositories and git worktrees

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/utility.sh"

select_git_folder_actx() {
	local programming_dir="$HOME/Programming"
	local selection_type="${1:-both}"

	local search_dirs=()
	while IFS= read -r org_dir; do
		[[ -d "$org_dir" ]] && search_dirs+=("${org_dir%/}")
	done < <(get_org_dirs "$programming_dir")

	if [[ ${#search_dirs[@]} -eq 0 ]]; then
		echo "Error: No org directories found in $programming_dir"
		return 1
	fi

	if ! command -v fzf &>/dev/null; then
		echo "Error: fzf is required but not installed"
		echo "Install with: brew install fzf"
		return 1
	fi

	local git_items=()

	case "$selection_type" in
	"repos")
		echo "Searching for git repositories..."
		for dir in "${search_dirs[@]}"; do
			local category="${dir##*/}"
			while IFS= read -r line; do
				[[ -n "$line" ]] && git_items+=("[$category] $line")
			done < <(find_git_repos "$dir" 1)
		done
		;;
	"worktrees")
		echo "Searching for git worktrees..."
		for dir in "${search_dirs[@]}"; do
			local category="${dir##*/}"
			while IFS= read -r line; do
				[[ -n "$line" ]] && git_items+=("[$category] $line")
			done < <(find_git_worktrees "$dir" 1)
		done
		;;
	"both" | *)
		echo "Searching for git repositories and worktrees..."
		for dir in "${search_dirs[@]}"; do
			local category="${dir##*/}"
			while IFS= read -r line; do
				[[ -n "$line" ]] && git_items+=("[$category] $line")
			done < <(find_git_repos_and_worktrees "$dir" 1)
		done
		;;
	esac

	# Check if any git items were found
	if [[ ${#git_items[@]} -eq 0 ]]; then
		case "$selection_type" in
		"repos")
			echo "No git repositories found"
			;;
		"worktrees")
			echo "No git worktrees found"
			;;
		*)
			echo "No git repositories or worktrees found"
			;;
		esac
		return 1
	fi

	echo "Found ${#git_items[@]} item(s)"

	# Use fzf to select an item, with fallback for non-interactive mode
	local selected_item
	local prompt_text

	case "$selection_type" in
	"repos")
		prompt_text="Select git repo: "
		;;
	"worktrees")
		prompt_text="Select git worktree: "
		;;
	*)
		prompt_text="Select git repo/worktree: "
		;;
	esac

	# Check if we're in an interactive terminal and fzf can work properly
	if [[ -t 0 && -t 1 ]] && command -v fzf &>/dev/null && [[ -n "$TERM" ]] && [[ "$TERM" != "dumb" ]]; then
		# Try fzf - if it works, great; if not, we'll fall back
		selected_item=$(printf '%s\n' "${git_items[@]}" | fzf --prompt="$prompt_text" --height=40% --border 2>/dev/null) || selected_item=""
	fi

	# If fzf failed or is not available, use fallback selection
	if [[ -z "$selected_item" ]]; then
		# Fallback: show numbered list and read selection
		echo "Available items:"
		for i in "${!git_items[@]}"; do
			echo "$((i + 1)). ${git_items[i]}"
		done

		echo -n "Enter item number (1-${#git_items[@]}): "
		read -r selection

		if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#git_items[@]}" ]]; then
			selected_item="${git_items[$((selection - 1))]}"
		else
			echo "Invalid selection"
			return 1
		fi
	fi

	# Check if selection was made
	if [[ -z "$selected_item" ]]; then
		echo "No item selected"
		return 1
	fi

	local category="${selected_item%%]*}"
	category="${category#[}"
	local item_name="${selected_item#*] }"
	local source_path="$programming_dir/$category/$item_name"
	local target_name="${item_name##*/}-actx"
	local target_path="$(pwd)/$target_name"

	# Check if source exists
	if [[ ! -d "$source_path" ]]; then
		echo "Error: Source directory $source_path not found"
		return 1
	fi

	# Check if target already exists
	if [[ -e "$target_path" ]]; then
		echo "Warning: $target_name already exists in current directory"
		read -p "Do you want to remove it and create a new symlink? (y/N): " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			rm -rf "$target_path"
		else
			echo "Operation cancelled"
			return 1
		fi
	fi

	# Determine item type for informative output
	local item_type
	if [[ -d "$source_path/.git" ]]; then
		item_type="repository"
	elif [[ -f "$source_path/.git" ]]; then
		item_type="worktree"
	else
		item_type="directory"
	fi

	# Create the symlink
	if ln -s "$source_path" "$target_path"; then
		echo "Successfully created symlink: $target_name -> $category/$item_name ($item_type)"
		echo "Source: $source_path"
		echo "Target: $target_path"
	else
		echo "Error: Failed to create symlink"
		return 1
	fi
}

# Function to show help
show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create a symlink with -actx suffix for git repositories and worktrees from ~/Programming org directories

OPTIONS:
  -r, --repos        Select from git repositories only
  -w, --worktrees    Select from git worktrees only  
  -b, --both         Select from both repositories and worktrees (default)
  -h, --help         Show this help message

EXAMPLES:
  $(basename "$0")           # Select from both repos and worktrees
  $(basename "$0") -r        # Select from repositories only
  $(basename "$0") -w        # Select from worktrees only

DESCRIPTION:
  This script scans ~/Programming org directories for git repositories and worktrees, allows you to
  select one interactively with fzf, and creates a symlink in the current directory
  with the format: {name}-actx -> ~/Programming/{category}/{selected-item}
  
  Git repositories are directories containing .git subdirectories.
  Git worktrees are directories containing .git files with gitdir: references.

EOF
}

# Main execution logic
main() {
	local selection_type="both"

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		-r | --repos)
			selection_type="repos"
			shift
			;;
		-w | --worktrees)
			selection_type="worktrees"
			shift
			;;
		-b | --both)
			selection_type="both"
			shift
			;;
		-h | --help)
			show_help
			return 0
			;;
		*)
			echo "Error: Unknown option '$1'"
			echo "Use --help for usage information"
			return 1
			;;
		esac
	done

	select_git_folder_actx "$selection_type"
}

# Run the main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
