#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SECRETS_DIR="$HOME/Programming/JimmyTranDev/secrets"

source "$DOTFILES_ROOT/etc/scripts/utils/logging.sh"

PASS=0
FAIL=0
WARN=0

check_pass() {
	log_success "$1"
	PASS=$((PASS + 1))
}

check_fail() {
	log_error "$1"
	FAIL=$((FAIL + 1))
}

check_warn() {
	log_warning "$1"
	WARN=$((WARN + 1))
}

check_command() {
	local cmd="$1"
	local desc="${2:-$cmd}"
	if command -v "$cmd" >/dev/null 2>&1; then
		check_pass "$desc installed ($(command -v "$cmd"))"
	else
		check_fail "$desc not found"
	fi
}

check_symlink() {
	local dest="$1"
	local expected_src="$2"
	local name=$(basename "$dest")

	if [ -L "$dest" ]; then
		local actual_src=$(readlink "$dest")
		if [ "$actual_src" = "$expected_src" ]; then
			check_pass "Symlink $name -> correct target"
		else
			check_warn "Symlink $name -> $actual_src (expected $expected_src)"
		fi
	elif [ -e "$dest" ]; then
		check_warn "$name exists but is not a symlink"
	else
		check_fail "Symlink $name missing ($dest)"
	fi
}

main() {
	log_header "Dotfiles Health Check" "$EMOJI_ROCKET"
	echo

	log_info "Checking shell environment..."
	if [ "$SHELL" = "$(which zsh 2>/dev/null)" ] || [[ "$SHELL" == */zsh ]]; then
		check_pass "Default shell is zsh"
	else
		check_warn "Default shell is $SHELL (expected zsh)"
	fi
	echo

	log_info "Checking required tools..."
	REQUIRED_TOOLS=(
		"git:Git"
		"nvim:Neovim"
		"fzf:FZF"
		"rg:Ripgrep"
		"fd:fd"
		"starship:Starship"
		"zellij:Zellij"
		"yazi:Yazi"
		"lazygit:Lazygit"
		"bat:bat"
		"jq:jq"
	)

	if [ "$(uname)" = "Darwin" ]; then
		REQUIRED_TOOLS+=(
			"brew:Homebrew"
			"yabai:Yabai"
			"skhd:skhd"
		)
	fi

	for tool_entry in "${REQUIRED_TOOLS[@]}"; do
		IFS=':' read -r cmd desc <<<"$tool_entry"
		check_command "$cmd" "$desc"
	done

	OPTIONAL_TOOLS=(
		"fnm:fnm (Node version manager)"
		"zoxide:zoxide"
		"gitleaks:gitleaks"
		"docker:Docker"
		"espanso:Espanso"
		"diffnav:diffnav (git diff pager)"
	)

	echo
	log_info "Checking optional tools..."
	for tool_entry in "${OPTIONAL_TOOLS[@]}"; do
		IFS=':' read -r cmd desc <<<"$tool_entry"
		if command -v "$cmd" >/dev/null 2>&1; then
			check_pass "$desc installed"
		else
			check_warn "$desc not found (optional)"
		fi
	done
	echo

	log_info "Checking gh extensions..."
	if command -v gh >/dev/null 2>&1; then
		gh_exts=$(gh extension list 2>/dev/null || true)
		for ext in "gh-dash" "gh-enhance"; do
			if echo "$gh_exts" | grep -q "$ext"; then
				check_pass "$ext installed"
			else
				check_warn "$ext not found (optional)"
			fi
		done
	else
		check_warn "gh not found, skipping gh extension checks"
	fi
	echo

	log_info "Checking symlinks..."
	SYMLINKS=(
		"$HOME/.zshrc|$DOTFILES_ROOT/src/.zshrc"
		"$HOME/.config/zellij|$DOTFILES_ROOT/src/zellij"
		"$HOME/.config/yazi|$DOTFILES_ROOT/src/yazi"
		"$HOME/.config/lazygit|$DOTFILES_ROOT/src/lazygit"
		"$HOME/.config/starship.toml|$DOTFILES_ROOT/src/starship.toml"
		"$HOME/.config/opencode|$DOTFILES_ROOT/src/opencode"
		"$HOME/.config/git/hooks|$DOTFILES_ROOT/src/git/hooks"
		"$HOME/.config/kitty|$DOTFILES_ROOT/src/kitty"
		"$HOME/.config/espanso|$DOTFILES_ROOT/src/espanso"
		"$HOME/.ideavimrc|$DOTFILES_ROOT/src/.ideavimrc"
		"$HOME/.gitignore_global|$DOTFILES_ROOT/src/.gitignore_global"
		"$HOME/.ssh|$SECRETS_DIR/ssh"
		"$HOME/.gitconfig|$SECRETS_DIR/.gitconfig"
		"$HOME/.npmrc|$SECRETS_DIR/.npmrc"
		"$HOME/.m2|$SECRETS_DIR/.m2"
		"$HOME/.config/espanso/match/personal.yml|$SECRETS_DIR/espanso/match/personal.yml"
	)

	if [ "$(uname)" = "Darwin" ]; then
		SYMLINKS+=(
			"$HOME/.config/ghostty|$DOTFILES_ROOT/src/ghostty"
			"$HOME/.config/skhd|$DOTFILES_ROOT/src/skhd"
			"$HOME/.config/yabai|$DOTFILES_ROOT/src/yabai"
		)
	elif [ "$(uname)" = "Linux" ]; then
		SYMLINKS+=(
			"$HOME/.config/hypr|$DOTFILES_ROOT/src/hypr"
		)
	fi

	for link_entry in "${SYMLINKS[@]}"; do
		IFS='|' read -r dest src <<<"$link_entry"
		check_symlink "$dest" "$src"
	done
	echo

	log_info "Checking directories..."
	REQUIRED_DIRS=(
		"$HOME/Programming:Programming directory"
		"$DOTFILES_ROOT:Dotfiles repository"
		"$DOTFILES_ROOT/src/nvim:Neovim config"
	)

	for dir_entry in "${REQUIRED_DIRS[@]}"; do
		IFS=':' read -r dir desc <<<"$dir_entry"
		if [ -d "$dir" ]; then
			check_pass "$desc exists"
		else
			check_fail "$desc missing ($dir)"
		fi
	done

	if [ -d "$HOME/Programming/JimmyTranDev/secrets" ]; then
		check_pass "Secrets directory exists"
	else
		check_warn "Secrets directory missing ($HOME/Programming/JimmyTranDev/secrets)"
	fi
	echo

	log_info "Checking git configuration..."
	local hooks_path
	hooks_path=$(git config --global core.hooksPath 2>/dev/null || true)
	if [ "$hooks_path" = "$HOME/.config/git/hooks" ]; then
		check_pass "Git hooks path configured"
	else
		check_warn "Git hooks path not set (expected $HOME/.config/git/hooks, got '$hooks_path')"
	fi

	local global_ignore
	global_ignore=$(git config --global core.excludesFile 2>/dev/null || true)
	if [ -n "$global_ignore" ]; then
		check_pass "Global gitignore configured ($global_ignore)"
	else
		check_warn "Global gitignore not configured"
	fi
	echo

	log_info "Checking SSH permissions..."
	if [ -d "$HOME/.ssh" ]; then
		local ssh_perms
		ssh_perms=$(stat -Lf "%Lp" "$HOME/.ssh" 2>/dev/null || stat -Lc "%a" "$HOME/.ssh" 2>/dev/null)
		if [ "$ssh_perms" = "700" ]; then
			check_pass "SSH directory permissions correct (700)"
		else
			check_fail "SSH directory permissions incorrect ($ssh_perms, expected 700)"
		fi
		if [ -f "$HOME/.ssh/id_ed25519" ]; then
			local key_perms
			key_perms=$(stat -Lf "%Lp" "$HOME/.ssh/id_ed25519" 2>/dev/null || stat -Lc "%a" "$HOME/.ssh/id_ed25519" 2>/dev/null)
			if [ "$key_perms" = "600" ]; then
				check_pass "SSH private key permissions correct (600)"
			else
				check_fail "SSH private key permissions incorrect ($key_perms, expected 600)"
			fi
		else
			check_warn "SSH private key not found"
		fi
	else
		check_warn "SSH directory not found"
	fi
	echo

	log_header "Health Check Summary" "$EMOJI_INFO"
	log_success "Passed: $PASS"
	log_warning "Warnings: $WARN"
	log_error "Failed: $FAIL"
	echo

	if [ $FAIL -gt 0 ]; then
		log_error "Some checks failed. Run the install script to fix: $DOTFILES_ROOT/etc/scripts/src/install/install.sh"
		exit 1
	elif [ $WARN -gt 0 ]; then
		log_warning "Some warnings found. Review the output above."
		exit 0
	else
		log_success "All checks passed!"
		exit 0
	fi
}

main "$@"
