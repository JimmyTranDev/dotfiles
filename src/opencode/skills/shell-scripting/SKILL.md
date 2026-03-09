---
name: shell-scripting
description: Shell scripting conventions for bash and zsh including error handling, naming, color output, and module patterns
---

## Shebang Selection

- `#!/bin/bash` — infrastructure scripts, install scripts, shared libraries, git hooks, anything requiring portability
- `#!/bin/zsh` — interactive daily-use scripts, worktree system, scripts using zsh-specific features (`print -P`, `${0:A:h}`, `zle` widgets)

## Error Handling

### Standalone scripts: `set -e` at the top
```bash
#!/bin/bash
set -e
```

### Strict mode for diagnostic scripts: `set -eo pipefail`
```bash
set -eo pipefail
```

### Sourced libraries and worktree commands: inline error handling
```zsh
git -C "$repo_dir" fetch origin || {
    print_color red "Failed to fetch from origin"
    return 1
}
```

### Tool existence: always `command -v`, never `which`
```bash
if ! command -v "$tool" &>/dev/null; then
    echo "Error: $tool not found"
    exit 1
fi
```

## Variable Naming

- **UPPERCASE**: global constants, exported env vars, color codes, emoji constants, boolean flags, arrays of items, regex patterns
- **lowercase with `local`**: function-local variables, parameters, loop vars, counters
- **snake_case exclusively** — no camelCase anywhere

```bash
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_TOOLS=("git" "nvim" "fzf")

my_function() {
    local branch_name="$1"
    local success_count=0
}
```

## Function Naming

- **snake_case** for all function names
- **Prefix namespacing** for related groups:
  - `cmd_` for CLI subcommands: `cmd_create`, `cmd_delete`
  - `log_` for logging: `log_info`, `log_success`, `log_error`
  - `check_` for health checks: `check_pass`, `check_fail`, `check_command`
  - `fzf_select_` for interactive selectors
- **verb_noun** for utilities: `get_org_dirs`, `find_git_repos`, `detect_package_manager`
- **`_` prefix** for private/internal functions: `_fzf_select_items_and_cd`
- **`main()`** as entry point for scripts with argument parsing

## Color Output

### Bash: ANSI escape codes
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
echo -e "${RED}Error${NC}"
```

### Zsh: `print -P` with `%F{color}`
```zsh
print_color() {
    local color="${1:-white}"
    shift
    print -P "%F{$color}$*%f"
}
print_color red "Error message"
print_color green "Success"
```

### Color semantics
- Red = errors/failures
- Green = success/pass
- Yellow = warnings/in-progress
- Cyan = informational/prompts
- Blue = headers/section titles

## Logging Library

Source `etc/scripts/common/logging.sh` for standardized logging:
```bash
log_info "message"       # Cyan + info emoji
log_success "message"    # Green + checkmark
log_error "message"      # Red + cross
log_warning "message"    # Yellow + warning
log_header "message"     # Blue + rocket emoji
```

## Module / Sourcing Pattern

### Script directory resolution
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"    # bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"                    # zsh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)" # cross-shell
```

### Modular architecture (worktree system pattern)
```zsh
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/jira.sh"
source "$SCRIPT_DIR/commands/create.sh"
```

### Conditional sourcing
```zsh
[[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
```

## Argument Parsing

### Flags with `case` + `shift`
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done
```

### Subcommand router
```zsh
main() {
    local command="$1"
    case "$command" in
        create)  shift; cmd_create "$@" ;;
        delete)  shift; cmd_delete "$@" ;;
        -h|--help|help) show_help ;;
        "") print_color red "Error: No command provided."; show_help; return 1 ;;
        *) print_color red "Error: Unknown command '$command'"; show_help; return 1 ;;
    esac
}
main "$@"
```

### Positional args with defaults
```bash
local candidate="${1:-java}"
```

## FZF Integration

fzf is the primary interactive selector:
```bash
selected=$(printf "%s\n" "${items[@]}" | fzf --prompt="Select: " --height=40% --border)
```

Multi-select:
```zsh
printf "%s\n" "$@" | fzf --multi --prompt="$prompt"
```

## Quoting Rules

- **Double-quote all variable expansions**: `"$variable"`, `"$SCRIPT_DIR/path"`
- **Double-quote command substitutions**: `output="$(command)"`
- **Single quotes for literals**: patterns, heredoc delimiters, grep/sed expressions
- **Unquoted only**: inside `[[ ]]`, array iteration, arithmetic

## Help/Usage

```bash
show_help() {
    cat << 'EOF'
Usage: script <command> [options]

COMMANDS:
  create    Create something
  delete    Delete something
EOF
}
```

## Summary Counters Pattern

```bash
local success_count=0 skip_count=0 total_count=0
# ... loop incrementing counters ...
log_info "  Created: $success_count"
log_info "  Skipped: $skip_count"
log_info "  Total: $total_count"
```

## Cleanup

```bash
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
```

## Platform Detection

```bash
if [ "$(uname)" == "Darwin" ]; then
    # macOS
elif [ "$(uname)" == "Linux" ]; then
    if [ -f /etc/arch-release ]; then
        # Arch Linux
    fi
fi
```
