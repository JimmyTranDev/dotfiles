#!/bin/zsh

cmd_create() {
	if ! check_tool git; then
		return 1
	fi

	if ! check_tool fzf; then
		return 1
	fi

	local jira_ticket=""
	local repo_name=""
	local commit_type=""
	local target_dir=""
	local no_prompt=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--branch)
			jira_ticket="$2"
			shift 2
			;;
		--repo)
			repo_name="$2"
			shift 2
			;;
		--type)
			commit_type="$2"
			shift 2
			;;
		--dir)
			target_dir="$2"
			shift 2
			;;
		--no-prompt)
			no_prompt=true
			shift
			;;
		-h|--help)
			echo "Usage: worktree create [OPTIONS] [jira-ticket] [repo-name]"
			echo ""
			echo "OPTIONS:"
			echo "  --branch <name>     Branch name or Jira ticket (skips interactive input)"
			echo "  --repo <name>       Repository name (skips fzf repo selection)"
			echo "  --type <type>       Commit type: feat|fix|chore|... (skips fzf selection)"
			echo "  --dir <dir>         Target directory: wcreated or wcheckout (skips selection)"
			echo "  --no-prompt         Skip all interactive prompts, use defaults"
			echo "  -h, --help          Show this help"
			return 0
			;;
		*)
			if [[ -z "$jira_ticket" ]]; then
				jira_ticket="$1"
			elif [[ -z "$repo_name" ]]; then
				repo_name="$1"
			fi
			shift
			;;
		esac
	done

	local main_repo
	if [[ -n "$repo_name" ]]; then
		print_color yellow "Looking for repository: $repo_name"
		main_repo=$(get_repository "$repo_name") || {
			print_color red "Error: Could not find repository '$repo_name'"
			return 1
		}
	else
		main_repo=$(get_repository) || {
			print_color red "Error: Repository selection failed"
			return 1
		}
	fi

	print_color yellow "Using repository: $(basename "$main_repo")"
	print_color yellow "Repository path: $main_repo"

	local main_branch
	main_branch=$(find_base_branch "$main_repo") || {
		print_color red "Error: Could not find main branch in $main_repo"
		return 1
	}

	print_color yellow "Base branch: $main_branch"

	print_color yellow "Fetching latest changes from origin..."
	git -C "$main_repo" fetch origin || {
		print_color yellow "Warning: Could not fetch from origin. Continuing with local state."
	}

	local current_branch
	current_branch=$(git -C "$main_repo" symbolic-ref --short HEAD 2>/dev/null)

	if [[ "$current_branch" == "$main_branch" ]]; then
		local stashed=false
		local uncommitted_files
		uncommitted_files=$(git -C "$main_repo" status --porcelain)

		if [[ -n "$uncommitted_files" ]]; then
			print_color yellow "Stashing uncommitted changes before pulling..."
			if git -C "$main_repo" stash push -m "worktree-create-auto-stash"; then
				stashed=true
			else
				print_color yellow "Warning: Could not stash changes. Skipping pull."
			fi
		fi

		if [[ "$stashed" == true ]] || [[ -z "$uncommitted_files" ]]; then
			print_color yellow "Pulling latest $main_branch..."
			if ! git -C "$main_repo" pull --rebase origin "$main_branch"; then
				print_color yellow "Warning: Pull failed. Aborting rebase if in progress."
				git -C "$main_repo" rebase --abort 2>/dev/null
			fi
		fi

		if [[ "$stashed" == true ]]; then
			print_color yellow "Restoring stashed changes..."
			git -C "$main_repo" stash pop || {
				print_color red "Warning: Could not restore stashed changes. Run 'git stash pop' manually."
			}
		fi
	else
		print_color yellow "Not on $main_branch, updating via fetch only."
		git -C "$main_repo" fetch origin "$main_branch:$main_branch" 2>/dev/null || {
			print_color yellow "Warning: Could not fast-forward $main_branch. Continuing with local state."
		}
	fi

	if [[ -z "$jira_ticket" ]]; then
		if [[ "$no_prompt" == true ]]; then
			print_color red "Error: --branch is required with --no-prompt"
			return 1
		fi
		print_color cyan "Enter JIRA ticket (e.g., ABC-123) or leave empty to skip JIRA integration:"
		read -r jira_ticket
	fi

	local branch_name=""
	local summary=""

	if [[ -n "$jira_ticket" && "$jira_ticket" =~ $JIRA_PATTERN ]]; then
		if ! check_tool acli; then
			print_color yellow "acli not available. Proceeding without JIRA integration."
			branch_name="$jira_ticket"
		else
			print_color yellow "Fetching JIRA ticket details..."

			summary=$(get_jira_summary "$jira_ticket" 2>/dev/null)
			if [[ $? -eq 0 && -n "$summary" ]]; then
				print_color green "✅ JIRA ticket found: $summary"
				local clean_summary
				clean_summary=$(slugify "$(echo "$summary" | head -1 | sed 's/\x1b\[[0-9;]*m//g')")
				branch_name="${jira_ticket}-${clean_summary}"
			else
				print_color yellow "Could not fetch JIRA summary. Using ticket number as branch name."
				branch_name="$jira_ticket"
			fi
		fi
	elif [[ -n "$jira_ticket" ]]; then
		branch_name="$jira_ticket"
		print_color yellow "Input doesn't match JIRA pattern. Using as branch name directly."
	else
		if [[ "$no_prompt" == true ]]; then
			print_color red "Error: --branch is required with --no-prompt"
			return 1
		fi
		print_color cyan "Enter branch name:"
		read -r branch_name

		if [[ -z "$branch_name" ]]; then
			print_color red "No branch name provided. Aborting."
			return 1
		fi
	fi

	local original_input="$branch_name"
	branch_name=$(echo "$branch_name" | head -1 | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\n\r' | sed 's/[^a-zA-Z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//')

	if [[ -z "$branch_name" ]]; then
		print_color red "Invalid branch name. Aborting."
		return 1
	fi

	print_color cyan "Creating worktree for branch: $branch_name"

	local commit_types=("feat" "fix" "docs" "style" "refactor" "test" "chore" "revert" "build" "ci" "perf")

	if [[ -z "$commit_type" ]]; then
		if [[ "$no_prompt" == true ]]; then
			commit_type="feat"
		else
			print_color cyan "Select commit type:"
			if check_tool fzf; then
				commit_type=$(printf '%s\n' "${commit_types[@]}" | fzf --prompt="Select commit type: " --height=40% --reverse)
			else
				echo "Available commit types:"
				for i in "${!commit_types[@]}"; do
					echo "$((i + 1)). ${commit_types[$i]}"
				done
				echo -n "Enter number (1-${#commit_types[@]}) or type name [default: feat]: "
				read -r selection

				if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#commit_types[@]}" ]]; then
					commit_type="${commit_types[$selection]}"
				elif [[ -n "$selection" ]]; then
					commit_type="$selection"
				else
					commit_type="feat"
				fi
			fi
		fi
	fi

	if [[ -z "$commit_type" ]]; then
		commit_type="feat"
	fi

	print_color green "Selected commit type: $commit_type"

	if [[ -z "$target_dir" ]]; then
		if [[ "$no_prompt" == true ]]; then
			target_dir="$WCREATED_DIR"
		else
			local dir_options=("wcreated" "wcheckout")
			local selected_dir
			selected_dir=$(select_fzf "Select worktree directory: " "${dir_options[@]}") || {
				print_color red "No directory selected. Aborting."
				return 1
			}
			case "$selected_dir" in
			"wcreated") target_dir="$WCREATED_DIR" ;;
			"wcheckout") target_dir="$WCHECKOUT_DIR" ;;
			*) target_dir="$WCREATED_DIR" ;;
			esac
		fi
	elif [[ "$target_dir" == "wcreated" ]]; then
		target_dir="$WCREATED_DIR"
	elif [[ "$target_dir" == "wcheckout" ]]; then
		target_dir="$WCHECKOUT_DIR"
	fi

	print_color yellow "Target directory: $target_dir"

	local worktree_dir
	worktree_dir=$(resolve_unique_dir "$target_dir/$branch_name")
	branch_name=$(basename "$worktree_dir")

	mkdir -p "$target_dir" || {
		print_color red "Error: Could not create worktrees directory: $target_dir"
		return 1
	}

	print_color yellow "Creating worktree at: $worktree_dir"

	git -C "$main_repo" worktree add -b "$branch_name" "$worktree_dir" "$main_branch" || {
		print_color red "Error: Failed to create worktree"
		return 1
	}

	print_color green "✅ Worktree created successfully!"
	print_color cyan "📁 Path: $worktree_dir"
	print_color cyan "🌿 Branch: $branch_name"

	print_color yellow "Creating initial commit..."
	local commit_message

	if [[ -n "$jira_ticket" && "$jira_ticket" =~ $JIRA_PATTERN ]]; then
		if [[ -n "$summary" ]]; then
			commit_message="$commit_type: $jira_ticket $summary"
		else
			commit_message="$commit_type: $jira_ticket"
		fi

		commit_message="$commit_message

Jira: https://${ORG_NAME}.atlassian.net/browse/${jira_ticket}"
	else
		commit_message="$commit_type: $original_input"
	fi

	git -C "$worktree_dir" commit --allow-empty -m "$commit_message" || {
		print_color yellow "Warning: Could not create initial commit"
	}

	if [[ -n "$summary" ]]; then
		print_color cyan "📋 JIRA: $jira_ticket - $summary"
	fi

	if [[ -f "$worktree_dir/package.json" ]]; then
		print_color yellow "📦 Package.json found. Installing dependencies..."

		cd "$worktree_dir" || {
			print_color yellow "Warning: Could not navigate to worktree directory for dependency installation"
		}

		local package_manager
		package_manager=$(detect_package_manager)

		if [[ -n "$package_manager" ]]; then
			print_color cyan "Using package manager: $package_manager"

			case "$package_manager" in
			"pnpm")
				if command -v pnpm >/dev/null 2>&1; then
					pnpm install
				else
					print_color yellow "pnpm not found, falling back to npm"
					npm install
				fi
				;;
			"yarn")
				if command -v yarn >/dev/null 2>&1; then
					yarn install
				else
					print_color yellow "yarn not found, falling back to npm"
					npm install
				fi
				;;
			"npm" | *)
				npm install
				;;
			esac
		else
			print_color yellow "No lock file found, using npm"
			npm install
		fi
	else
		print_color cyan "No package.json found, skipping dependency installation"
		cd "$worktree_dir" || {
			print_color yellow "Warning: Could not navigate to worktree directory"
		}
	fi

	print_color yellow "Now in worktree directory. Happy coding! 🚀"
}
