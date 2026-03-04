#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/common/logging.sh"

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

log_header "Dotfiles Health Check" "$EMOJI_ROCKET"
echo

log_info "Checking shell environment..."
if [ "$SHELL" = "$(which zsh 2>/dev/null)" ] || [[ "$SHELL" == */zsh ]]; then
	check_pass "Default shell is zsh"
else
	check_warn "Default shell is $SHELL (expected zsh)"
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
	check_pass "Oh My Zsh installed"
else
	check_fail "Oh My Zsh not installed"
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
	"trufflehog:TruffleHog"
	"docker:Docker"
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

log_info "Checking symlinks..."
SYMLINKS=(
	"$HOME/.zshrc|$DOTFILES_ROOT/src/.zshrc"
	"$HOME/.config/zellij|$DOTFILES_ROOT/src/zellij"
	"$HOME/.config/yazi|$DOTFILES_ROOT/src/yazi"
	"$HOME/.config/lazygit|$DOTFILES_ROOT/src/lazygit"
	"$HOME/.config/starship.toml|$DOTFILES_ROOT/src/starship.toml"
	"$HOME/.config/btop|$DOTFILES_ROOT/src/btop"
	"$HOME/.config/opencode|$DOTFILES_ROOT/src/opencode"
	"$HOME/.config/git/hooks|$DOTFILES_ROOT/src/git/hooks"
	"$HOME/.ideavimrc|$DOTFILES_ROOT/src/.ideavimrc"
	"$HOME/.gitignore_global|$DOTFILES_ROOT/src/.gitignore_global"
)

if [ "$(uname)" = "Darwin" ]; then
	SYMLINKS+=(
		"$HOME/.config/ghostty|$DOTFILES_ROOT/src/ghostty"
		"$HOME/.config/skhd|$DOTFILES_ROOT/src/skhd"
		"$HOME/.config/yabai|$DOTFILES_ROOT/src/yabai"
		"$HOME/.config/kitty|$DOTFILES_ROOT/src/kitty"
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
	"$HOME/Programming/nvim:Neovim config"
)

for dir_entry in "${REQUIRED_DIRS[@]}"; do
	IFS=':' read -r dir desc <<<"$dir_entry"
	if [ -d "$dir" ]; then
		check_pass "$desc exists"
	else
		check_fail "$desc missing ($dir)"
	fi
done

if [ -d "$HOME/Programming/secrets" ]; then
	check_pass "Secrets directory exists"
else
	check_warn "Secrets directory missing ($HOME/Programming/secrets)"
fi
echo

log_info "Checking git configuration..."
HOOKS_PATH=$(git config --global core.hooksPath 2>/dev/null || true)
if [ "$HOOKS_PATH" = "$HOME/.config/git/hooks" ]; then
	check_pass "Git hooks path configured"
else
	check_warn "Git hooks path not set (expected $HOME/.config/git/hooks, got '$HOOKS_PATH')"
fi

GLOBAL_IGNORE=$(git config --global core.excludesFile 2>/dev/null || true)
if [ -n "$GLOBAL_IGNORE" ]; then
	check_pass "Global gitignore configured ($GLOBAL_IGNORE)"
else
	check_warn "Global gitignore not configured"
fi
echo

log_header "Health Check Summary" "$EMOJI_INFO"
echo -e "  ${GREEN}${EMOJI_SUCCESS} Passed: $PASS${NC}"
echo -e "  ${YELLOW}${EMOJI_WARNING} Warnings: $WARN${NC}"
echo -e "  ${RED}${EMOJI_ERROR} Failed: $FAIL${NC}"
echo

if [ $FAIL -gt 0 ]; then
	log_error "Some checks failed. Run the install script to fix: $DOTFILES_ROOT/etc/scripts/install.sh"
	exit 1
elif [ $WARN -gt 0 ]; then
	log_warning "Some warnings found. Review the output above."
	exit 0
else
	log_success "All checks passed!"
	exit 0
fi
