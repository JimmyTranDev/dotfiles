# Worktree CLI

A CLI tool for managing Git worktrees. This Go application helps you create, manage, and clean up Git worktrees efficiently with an improved user experience.

## Features

### ✅ Implemented
- **Git Worktree Management**: Create, list, delete, and clean worktrees
- **Repository Discovery**: Find and list Git repositories in your development directories
- **Interactive UI**: Colored output and interactive prompts using promptui
- **Branch Creation**: Create new branches with proper base branch handling
- **Package Manager Detection**: Auto-detect and install dependencies (npm/yarn/pnpm)
- **Commit Type Selection**: Interactive selection of conventional commit types
- **Configuration Management**: YAML-based configuration with environment variable overrides
- **Error Handling**: Comprehensive error types with proper context

## Installation

### Prerequisites
- Go 1.22 or later
- Git

### Build from Source
```bash
git clone <repository-url>
cd worktree-cli
make build
```

### Install
```bash
# Copy to your PATH (e.g., ~/.local/bin or /usr/local/bin)
cp worktree ~/.local/bin/
```

## Configuration

The CLI uses a YAML configuration file located at `~/.config/worktree-cli/config.yaml`. On first run, a default configuration is created automatically.

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

ui:
  color_enabled: true
  interactive: true
```

### Environment Variables
You can override configuration values using environment variables with the `WORKTREE_` prefix:

```bash
export WORKTREE_WORKTREES_DIR="/custom/worktrees/path"
export WORKTREE_PROGRAMMING_DIR="/custom/programming/path"
```

## Usage

### Worktree Management

```bash
# List all worktrees
worktree list

# Create a new worktree (interactive)
worktree create

# Create a worktree with specific branch
worktree create feature/new-feature

# Create a worktree with specific branch and repo
worktree create feature/new-feature -r /path/to/repo

# Delete a worktree (interactive selection)
worktree delete

# Delete specific worktree
worktree delete /path/to/worktree

# Clean up stale worktrees
worktree clean --dry-run=false
```

## Architecture

The CLI follows clean architecture principles with clear separation of concerns:

```
cmd/                    # CLI commands (Cobra)
├── root.go            # Command setup
└── worktree.go        # Worktree commands

internal/              # Internal packages
├── config/            # Configuration management
├── domain/            # Domain types and entities
├── git/               # Git operations
└── ui/                # User interface helpers

pkg/                   # Public packages
└── errors/            # Error types and handling
```

## Security Improvements

This Go CLI addresses several security vulnerabilities found in shell scripts:

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

## License

[Your License Here]