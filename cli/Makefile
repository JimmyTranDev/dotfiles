# Worktree CLI Makefile
# Build and install the worktree management CLI

# Binary name
BINARY_NAME = worktree

# Version information
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build flags
LDFLAGS = -ldflags "-X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(DATE)"

# Install paths
INSTALL_PATH = /usr/local/bin
COMPLETION_PATH = /usr/local/share/bash-completion/completions

# Colors for output
GREEN = \033[32m
YELLOW = \033[33m
BLUE = \033[34m
RESET = \033[0m

.PHONY: all build install uninstall clean test fmt lint help dev completion

# Default target
all: build

help: ## Show this help message
	@echo "$(BLUE)Worktree CLI Build System$(RESET)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-12s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the CLI binary locally
	@echo "$(BLUE)Building worktree CLI...$(RESET)"
	@echo "  Version: $(VERSION)"
	@echo "  Commit:  $(COMMIT)"
	@echo "  Date:    $(DATE)"
	@go build $(LDFLAGS) -o $(BINARY_NAME) .
	@echo "$(GREEN)✓ Build complete: ./$(BINARY_NAME)$(RESET)"

install: build ## Build and install globally to /usr/local/bin
	@echo "$(BLUE)Installing worktree CLI globally...$(RESET)"
	@sudo mkdir -p $(INSTALL_PATH)
	@sudo cp $(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@sudo chmod +x $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "$(GREEN)✓ Installed to $(INSTALL_PATH)/$(BINARY_NAME)$(RESET)"
	@echo ""
	@echo "$(YELLOW)You can now run 'worktree' from anywhere!$(RESET)"
	@echo "Try: $(GREEN)worktree --help$(RESET)"

uninstall: ## Remove the CLI from global installation
	@echo "$(BLUE)Uninstalling worktree CLI...$(RESET)"
	@sudo rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	@sudo rm -f $(COMPLETION_PATH)/$(BINARY_NAME)
	@echo "$(GREEN)✓ Uninstalled $(BINARY_NAME)$(RESET)"

completion: install ## Generate and install shell completions
	@echo "$(BLUE)Installing shell completions...$(RESET)"
	@sudo mkdir -p $(COMPLETION_PATH)
	@$(BINARY_NAME) completion bash | sudo tee $(COMPLETION_PATH)/$(BINARY_NAME) > /dev/null
	@echo "$(GREEN)✓ Bash completion installed to $(COMPLETION_PATH)/$(BINARY_NAME)$(RESET)"
	@echo "$(YELLOW)Restart your shell or run: source $(COMPLETION_PATH)/$(BINARY_NAME)$(RESET)"

dev: ## Build and install for development (with dev version)
	@$(MAKE) VERSION=dev-$(shell date +%s) install

test: ## Run tests
	@echo "$(BLUE)Running tests...$(RESET)"
	@go test -v ./...
	@echo "$(GREEN)✓ Tests completed$(RESET)"

fmt: ## Format Go code
	@echo "$(BLUE)Formatting code...$(RESET)"
	@go fmt ./...
	@echo "$(GREEN)✓ Code formatted$(RESET)"

lint: ## Run linter
	@echo "$(BLUE)Running linter...$(RESET)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
		echo "$(GREEN)✓ Linting completed$(RESET)"; \
	else \
		echo "$(YELLOW)⚠ golangci-lint not installed, running go vet instead$(RESET)"; \
		go vet ./...; \
	fi

clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(RESET)"
	@rm -f $(BINARY_NAME)
	@go clean
	@echo "$(GREEN)✓ Clean completed$(RESET)"

# Build for multiple platforms
build-all: ## Build for multiple platforms
	@echo "$(BLUE)Building for multiple platforms...$(RESET)"
	@mkdir -p dist
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-darwin-amd64 .
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-darwin-arm64 .
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-linux-amd64 .
	@GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-linux-arm64 .
	@echo "$(GREEN)✓ Multi-platform builds completed in ./dist/$(RESET)"

# Release build with version validation
release: ## Create a release build (requires VERSION env var)
ifndef VERSION
	$(error VERSION is required. Usage: make release VERSION=v1.0.0)
endif
	@echo "$(BLUE)Creating release build $(VERSION)...$(RESET)"
	@$(MAKE) build-all VERSION=$(VERSION)
	@echo "$(GREEN)✓ Release $(VERSION) created in ./dist/$(RESET)"

# Quick install without rebuild
quick-install: ## Quick install (assumes binary already exists)
	@if [ ! -f $(BINARY_NAME) ]; then \
		echo "$(YELLOW)Binary not found, building first...$(RESET)"; \
		$(MAKE) build; \
	fi
	@echo "$(BLUE)Quick installing...$(RESET)"
	@sudo cp $(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@sudo chmod +x $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "$(GREEN)✓ Quick install completed$(RESET)"

# Development workflow
dev-watch: ## Development mode with file watching (requires entr)
	@if ! command -v entr >/dev/null 2>&1; then \
		echo "$(YELLOW)entr not installed. Install with: brew install entr$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Starting development mode with file watching...$(RESET)"
	@echo "$(YELLOW)Watching for changes in *.go files$(RESET)"
	@find . -name "*.go" | entr -c make dev

# Check installation
check: ## Check if worktree CLI is properly installed
	@echo "$(BLUE)Checking installation...$(RESET)"
	@if command -v worktree >/dev/null 2>&1; then \
		echo "$(GREEN)✓ worktree CLI is installed$(RESET)"; \
		echo "  Location: $$(which worktree)"; \
		echo "  Version:  $$(worktree --version)"; \
	else \
		echo "$(YELLOW)⚠ worktree CLI is not installed globally$(RESET)"; \
		echo "Run: $(GREEN)make install$(RESET)"; \
	fi

# Show version info
version: ## Show version information
	@echo "$(BLUE)Version Information:$(RESET)"
	@echo "  Version: $(VERSION)"
	@echo "  Commit:  $(COMMIT)"
	@echo "  Date:    $(DATE)"

# Update dependencies
deps: ## Update Go dependencies
	@echo "$(BLUE)Updating dependencies...$(RESET)"
	@go mod tidy
	@go mod download
	@echo "$(GREEN)✓ Dependencies updated$(RESET)"

# Verify build works
verify: build ## Verify the build works correctly
	@echo "$(BLUE)Verifying build...$(RESET)"
	@./$(BINARY_NAME) --version
	@./$(BINARY_NAME) --help > /dev/null
	@echo "$(GREEN)✓ Build verification passed$(RESET)"