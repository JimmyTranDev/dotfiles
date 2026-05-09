#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/utility.sh"
source "$SCRIPT_DIR/../utils/logging.sh"

select_git_folder_actx() {
	local programming_dir="$HOME/Programming"
	local selection_type="${1:-both}"

	local search_dirs=()
	while IFS= read -r org_dir; do
		[[ -d "$org_dir" ]] && search_dirs+=("${org_dir%/}")
	done < <(get_org_dirs "$programming_dir")

	if [[ ${#search_dirs[@]} -eq 0 ]]; then
		log_error "No org directories found in $programming_dir"
		return 1
	fi

	if ! command -v fzf &>/dev/null; then
		log_error "fzf is required but not installed"
		log_info "Install with: brew install fzf"
		return 1
	fi

	local git_items=()

	case "$selection_type" in
	"repos")
		log_info "Searching for git repositories..."
		for dir in "${search_dirs[@]}"; do
			local category="${dir##*/}"
			while IFS= read -r line; do
				[[ -n "$line" ]] && git_items+=("[$category] $line")
			done < <(find_git_repos "$dir" 1)
		done
		;;
	"worktrees")
		log_info "Searching for git worktrees..."
		for dir in "${search_dirs[@]}"; do
			local category="${dir##*/}"
			while IFS= read -r line; do
				[[ -n "$line" ]] && git_items+=("[$category] $line")
			done < <(find_git_worktrees "$dir" 1)
		done
		;;
	"both" | *)
		log_info "Searching for git repositories and worktrees..."
		for dir in "${search_dirs[@]}"; do
			local category="${dir##*/}"
			while IFS= read -r line; do
				[[ -n "$line" ]] && git_items+=("[$category] $line")
			done < <(find_git_repos_and_worktrees "$dir" 1)
		done
		;;
	esac

	if [[ ${#git_items[@]} -eq 0 ]]; then
		case "$selection_type" in
		"repos")
			log_warning "No git repositories found"
			;;
		"worktrees")
			log_warning "No git worktrees found"
			;;
		*)
			log_warning "No git repositories or worktrees found"
			;;
		esac
		return 1
	fi

	log_info "Found ${#git_items[@]} item(s)"

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

	if [[ -t 0 && -t 1 ]] && command -v fzf &>/dev/null && [[ -n "$TERM" ]] && [[ "$TERM" != "dumb" ]]; then
		selected_item=$(printf '%s\n' "${git_items[@]}" | fzf --prompt="$prompt_text" --height=40% --border 2>/dev/null) || selected_item=""
	fi

	if [[ -z "$selected_item" ]]; then
		echo "Available items:"
		for i in "${!git_items[@]}"; do
			echo "$((i + 1)). ${git_items[i]}"
		done

		echo -n "Enter item number (1-${#git_items[@]}): "
		read -r selection

		if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#git_items[@]}" ]]; then
			selected_item="${git_items[$((selection - 1))]}"
		else
			log_error "Invalid selection"
			return 1
		fi
	fi

	if [[ -z "$selected_item" ]]; then
		log_warning "No item selected"
		return 1
	fi

	local category="${selected_item%%]*}"
	category="${category#[}"
	local item_name="${selected_item#*] }"
	local source_path="$programming_dir/$category/$item_name"
	local target_name="${item_name##*/}-actx"
	local target_path="$(pwd)/$target_name"

	if [[ ! -d "$source_path" ]]; then
		log_error "Source directory $source_path not found"
		return 1
	fi

	if [[ -e "$target_path" ]]; then
		log_warning "$target_name already exists in current directory"
		read -p "Do you want to remove it and create a new symlink? (y/N): " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			rm -rf "$target_path"
		else
			log_info "Operation cancelled"
			return 1
		fi
	fi

	local item_type
	if [[ -d "$source_path/.git" ]]; then
		item_type="repository"
	elif [[ -f "$source_path/.git" ]]; then
		item_type="worktree"
	else
		item_type="directory"
	fi

	if ln -s "$source_path" "$target_path"; then
		log_success "Created symlink: $target_name -> $category/$item_name ($item_type)"
		log_info "Source: $source_path"
		log_info "Target: $target_path"
	else
		log_error "Failed to create symlink"
		return 1
	fi
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create a symlink with -actx suffix for git repositories and worktrees from ~/Programming org directories

OPTIONS:
  -r, --repos        Select from git repositories only
  -w, --worktrees    Select from git worktrees only  
  -b, --both         Select from both repositories and worktrees (default)
  -h, --help         Show this help message

EOF
}

main() {
	local selection_type="both"

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
			log_error "Unknown option '$1'"
			log_info "Use --help for usage information"
			return 1
			;;
		esac
	done

	select_git_folder_actx "$selection_type"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
