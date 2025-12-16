# Dotfiles CLI

A unified CLI tool for managing dotfiles, Git worktrees, themes, and development workflow. This Go application consolidates the functionality from various shell scripts into a single, maintainable CLI with improved error handling and user experience.

## Features

### ✅ Implemented
- **Git Worktree Management**: Create, list, delete, and clean worktrees
- **Theme Management**: Switch themes across multiple applications (Ghostty, Zellij, btop)
- **Project Discovery**: Find and list Git repositories in your development directories
- **Configuration Management**: YAML-based configuration with environment variable overrides
- **Interactive UI**: Colored output and interactive prompts using promptui
- **Error Handling**: Comprehensive error types with proper context

### 🚧 Planned
- **JIRA Integration**: Create worktrees from JIRA tickets with automatic branch naming
- **Storage Sync**: Backup and sync secrets/configurations to cloud storage (B2)
- **Advanced Project Management**: Package manager detection and dependency installation
- **Theme System**: Complete theme switching with file templating
- **Comprehensive Testing**: Unit and integration tests

## Installation

### Prerequisites
- Go 1.22 or later
- Git

### Build from Source
```bash
git clone <repository-url>
cd dotfiles-cli
./build.sh
```

### Install
```bash
# Copy to your PATH (e.g., ~/.local/bin or /usr/local/bin)
cp dotfiles ~/.local/bin/
```

## Configuration

The CLI uses a YAML configuration file located at `~/.config/dotfiles-cli/config.yaml`. On first run, a default configuration is created automatically.

### Default Configuration
```yaml
directories:
  worktrees: ~/Worktrees      # Where worktrees are created
  programming: ~/Programming  # Where to search for repositories
  home: ~

git:
  default_branch: main
  remotes: [origin]
  max_depth: 3               # How deep to search for repositories

themes:
  current: catppuccin-mocha
  available:
    - catppuccin-mocha
    - catppuccin-frappe
    - catppuccin-latte
    - catppuccin-macchiato
  paths:
    ghostty: ~/.config/ghostty/config
    zellij: ~/.config/zellij/config.kdl
    btop: ~/.config/btop/btop.conf

ui:
  color_enabled: true
  interactive: true
```

### Environment Variables
You can override configuration values using environment variables with the `DOTFILES_` prefix:

```bash
export DOTFILES_WORKTREES_DIR="/custom/worktrees/path"
export DOTFILES_PROGRAMMING_DIR="/custom/programming/path"
export DOTFILES_JIRA_BASE_URL="https://yourcompany.atlassian.net"
export DOTFILES_JIRA_TOKEN="your-jira-token"
```

## Usage

### Worktree Management

```bash
# List all worktrees
dotfiles worktree list

# Create a new worktree (interactive)
dotfiles worktree create

# Create a worktree with specific branch
dotfiles worktree create feature/new-feature

# Create a worktree with JIRA integration
dotfiles worktree create -j ABC-123 -b feature/new-feature

# Delete a worktree (interactive selection)
dotfiles worktree delete

# Delete specific worktree
dotfiles worktree delete /path/to/worktree

# Clean up stale worktrees
dotfiles worktree clean --dry-run=false
```

### Theme Management

```bash
# List available themes
dotfiles theme list

# Show current theme
dotfiles theme current

# Set theme (planned)
dotfiles theme set catppuccin-frappe
```

### Project Management

```bash
# List projects (planned)
dotfiles project list

# Select and open project (planned) 
dotfiles project select

# Sync project metadata (planned)
dotfiles project sync
```

## Architecture

The CLI follows clean architecture principles with clear separation of concerns:

```
cmd/                    # CLI commands (Cobra)
├── root.go            # Command setup
├── worktree.go        # Worktree commands
└── theme.go           # Theme commands

internal/              # Internal packages
├── config/            # Configuration management
├── domain/            # Domain types and entities
├── git/               # Git operations
├── project/           # Project management (planned)
├── theme/             # Theme management (planned)
├── jira/              # JIRA integration (planned)
└── ui/                # User interface helpers (planned)

pkg/                   # Public packages
└── errors/            # Error types and handling
```

## Security Improvements

This Go CLI addresses several security vulnerabilities found in the original shell scripts:

- **Command Injection Prevention**: Proper command execution using `os/exec`
- **Input Sanitization**: Validation of all user inputs
- **Path Traversal Protection**: Absolute path validation
- **Atomic Operations**: Safe file operations with proper cleanup
- **Structured Logging**: Secure error reporting without sensitive data

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Comparison with Original Scripts

| Feature | Shell Scripts | Go CLI | Benefits |
|---------|---------------|--------|----------|
| Worktree Management | ✅ Full | ✅ Full | Better error handling, type safety |
| Theme Switching | ✅ Full | 🚧 Partial | Planned: Better validation, atomic updates |
| Project Selection | ✅ Full | 🚧 Basic | Planned: FZF integration, caching |
| JIRA Integration | ✅ Full | 🚧 Planned | Planned: Better API handling, validation |
| Storage Sync | ✅ Full | 🚧 Planned | Planned: Structured config, error handling |
| Error Handling | ❌ Poor | ✅ Excellent | Structured errors, proper propagation |
| Testing | ❌ None | 🚧 Planned | Unit and integration tests |
| Security | ❌ Vulnerable | ✅ Secure | Input validation, injection prevention |
| Maintainability | ❌ Poor | ✅ Excellent | Type safety, modular architecture |

## License

[Your License Here]