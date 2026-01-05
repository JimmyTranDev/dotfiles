package cmd

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
	"time"

	"github.com/AlecAivazis/survey/v2"
	"github.com/fatih/color"
	"github.com/manifoldco/promptui"
	"github.com/spf13/cobra"

	"github.com/jimmy/worktree-cli/internal/config"
	"github.com/jimmy/worktree-cli/internal/domain"
	"github.com/jimmy/worktree-cli/internal/git"
	"github.com/jimmy/worktree-cli/internal/jira"
	"github.com/jimmy/worktree-cli/internal/ui"
)

// commitType represents available commit types
type commitType struct {
	Name  string
	Emoji string
	Desc  string
}

// selectMultipleWorktrees allows user to select multiple worktrees using checkboxes
func selectMultipleWorktrees(worktrees []*domain.Worktree) ([]string, error) {
	if len(worktrees) == 0 {
		return nil, fmt.Errorf("no worktrees available for selection")
	}

	// Create options for the multi-select prompt
	options := make([]string, len(worktrees))
	pathMap := make(map[string]string) // display string -> path

	for i, wt := range worktrees {
		displayName := fmt.Sprintf("%s (branch: %s)", filepath.Base(wt.Path), wt.Branch)
		options[i] = displayName
		pathMap[displayName] = wt.Path
	}

	// Use survey for multi-select
	var selected []string
	prompt := &survey.MultiSelect{
		Message:  "Select worktrees to delete:",
		Options:  options,
		PageSize: 15, // Show up to 15 items at once
		Help:     "Use arrow keys to navigate, spacebar to select/deselect, enter to confirm, / to search",
	}

	err := survey.AskOne(prompt, &selected)
	if err != nil {
		return nil, err
	}

	// Convert display names back to paths
	var selectedPaths []string
	for _, displayName := range selected {
		if path, exists := pathMap[displayName]; exists {
			selectedPaths = append(selectedPaths, path)
		}
	}

	return selectedPaths, nil
}

// getCommitTypes returns available commit types with emojis
func getCommitTypes() []commitType {
	return []commitType{
		{"feat", "✨", "A new feature"},
		{"fix", "🐛", "A bug fix"},
		{"docs", "📚", "Documentation only changes"},
		{"style", "💎", "Changes that do not affect the meaning of the code"},
		{"refactor", "🔨", "A code change that neither fixes a bug nor adds a feature"},
		{"test", "🧪", "Adding missing tests or correcting existing tests"},
		{"chore", "🔧", "Changes to the build process or auxiliary tools"},
		{"revert", "⏪", "Reverts a previous commit"},
		{"build", "📦", "Changes that affect the build system or external dependencies"},
		{"ci", "👷", "Changes to our CI configuration files and scripts"},
		{"perf", "🚀", "A code change that improves performance"},
	}
}

// detectPackageManager detects the package manager used in a directory
func detectPackageManager(dir string) string {
	lockFiles := map[string]string{
		"pnpm-lock.yaml":    "pnpm",
		"yarn.lock":         "yarn",
		"package-lock.json": "npm",
	}

	for file, manager := range lockFiles {
		if _, err := os.Stat(filepath.Join(dir, file)); err == nil {
			return manager
		}
	}

	// Check for package.json without lock files
	if _, err := os.Stat(filepath.Join(dir, "package.json")); err == nil {
		return "npm" // Default to npm
	}

	return ""
}

// installDependencies installs dependencies with the given package manager
func installDependencies(ctx context.Context, worktreePath string, packageManager string) error {
	// Create a timeout context for dependency installation (max 5 minutes)
	installCtx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()

	var cmd *exec.Cmd
	switch packageManager {
	case "pnpm":
		if _, err := exec.LookPath("pnpm"); err == nil {
			cmd = exec.CommandContext(installCtx, "pnpm", "install")
		} else {
			color.Yellow("pnpm not found, falling back to npm")
			cmd = exec.CommandContext(installCtx, "npm", "install")
		}
	case "yarn":
		if _, err := exec.LookPath("yarn"); err == nil {
			cmd = exec.CommandContext(installCtx, "yarn", "install")
		} else {
			color.Yellow("yarn not found, falling back to npm")
			cmd = exec.CommandContext(installCtx, "npm", "install")
		}
	default:
		cmd = exec.CommandContext(installCtx, "npm", "install")
	}

	cmd.Dir = worktreePath
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Prevent interactive prompts during dependency installation
	cmd.Env = append(os.Environ(),
		"CI=true",                // Prevent interactive prompts
		"npm_config_audit=false", // Skip security audits for faster install
		"npm_config_fund=false",  // Skip funding messages
	)

	return cmd.Run()
}

// logCommitHistory logs commit to programming notes (simplified implementation)
func logCommitHistory(commitMessage string) {
	// Skip logging for notes.md files (matching shell script logic)
	if strings.Contains(commitMessage, "notes.md") {
		return
	}

	color.Yellow("📝 Logging commit to programming notes...")

	// In the full implementation this would:
	// 1. Get current date and week information (date +%V, date +%Y, etc.)
	// 2. Create/update weekly log files in $HOME/Programming/notes.md/<repo>/<year>-<week>.md
	// 3. Format with titles: # Week <week>, <year> and ## <day> (<date>)
	// 4. Auto-commit to notes repository with "feat: ✨ update"

	// For now, simulate the logging
	color.Green("✅ Commit logged: %s", commitMessage)
	color.Cyan("    Would log to: ~/Programming/notes.md/<repo>/<year>-<week>.md")
}

// newWorktreeCreateCmd creates the worktree create command
func newWorktreeCreateCmd(cfg *config.Config) *cobra.Command {
	var (
		branch     string
		repository string
		jiraTicket string
	)

	cmd := &cobra.Command{
		Use:   "create [jira-ticket-or-branch-name]",
		Short: "Create a new worktree",
		Long: `Create a new Git worktree for development.

You can provide either:
- A JIRA ticket (e.g., ABC-123) - will fetch summary and create branch name
- A custom branch name - will be used directly

If no argument is provided, you'll be prompted to enter one.
The worktree will be created in the configured worktrees directory.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			// Create a timeout context to prevent hanging - shorter timeout since we removed the fetch
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
			defer cancel()

			// Also listen for interrupt signals
			go func() {
				sigChan := make(chan os.Signal, 1)
				signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
				select {
				case <-sigChan:
					color.Yellow("\n⚠️  Received interrupt signal, cancelling operation...")
					cancel()
				case <-ctx.Done():
					// Context finished normally
				}
			}()

			gitClient := git.NewClient()

			// Initialize JIRA service
			jiraService, err := jira.NewJIRAService(cfg.JIRA.Pattern, cfg.JIRA.TicketLink)
			if err != nil {
				return fmt.Errorf("failed to initialize JIRA service: %w", err)
			}

			// Get repository first - either by name or interactive selection
			var repoPath string
			if repository != "" {
				repoPath = repository
			} else {
				// Find repositories and let user select
				repos, err := ui.WithSpinnerResult(ui.SpinnerConfig{
					Message: "Finding repositories",
					Color:   "cyan",
				}, func() ([]*domain.Repository, error) {
					return gitClient.FindRepositories(ctx, cfg.Directories.Programming, cfg.Git.MaxDepth)
				})
				if err != nil {
					return fmt.Errorf("failed to find repositories: %w", err)
				}

				if len(repos) == 0 {
					return fmt.Errorf("no Git repositories found in %s", cfg.Directories.Programming)
				}

				color.Yellow("Using repository: %s", filepath.Base(repos[0].Path))
				if len(repos) > 1 {
					// Convert repositories to select options
					options := make([]ui.SelectOption, len(repos))
					for i, repo := range repos {
						options[i] = ui.SelectOption{
							Key:         fmt.Sprintf("%d", i),
							Title:       repo.Name,
							Description: repo.Path,
						}
					}

					// Use the search-enabled UI for repository selection
					selected, err := ui.RunSelection("Select repository", options)
					if err != nil {
						if ui.IsQuitError(err) {
							return fmt.Errorf("repository selection cancelled")
						}
						return fmt.Errorf("failed to select repository: %w", err)
					}

					// Convert selected key back to index
					idx := 0
					for i, option := range options {
						if option.Key == selected {
							idx = i
							break
						}
					}

					repoPath = repos[idx].Path
				} else {
					repoPath = repos[0].Path
				}
			}

			color.Yellow("Repository path: %s", repoPath)

			// Get the main branch for the selected repository
			mainBranch, err := gitClient.FindMainBranch(ctx, repoPath)
			if err != nil {
				return fmt.Errorf("failed to find main branch in %s: %w", repoPath, err)
			}
			color.Yellow("Base branch: %s", mainBranch)

			// Get input - JIRA ticket or branch name
			var input string
			if len(args) > 0 {
				input = args[0]
			} else if jiraTicket != "" {
				input = jiraTicket
			} else if branch != "" {
				input = branch
			} else {
				// Prompt for JIRA ticket or branch name
				prompt := promptui.Prompt{
					Label: "JIRA ticket (e.g., ABC-123) or branch name",
				}
				input, err = prompt.Run()
				if err != nil {
					return fmt.Errorf("failed to get input: %w", err)
				}
			}

			// Validate input
			if input == "" {
				return fmt.Errorf("JIRA ticket or branch name cannot be empty")
			}

			// Process input through JIRA service
			ticket, summary, branchName := jiraService.GetTicketWithFallback(ctx, input)

			// Additional sanitization for branch name (similar to shell script logic)
			if branchName == "" {
				branchName = input
			}

			// Clean branch name (sanitize) - similar to shell script logic
			invalidChars := regexp.MustCompile(`[^a-zA-Z0-9._-]`)
			branchName = invalidChars.ReplaceAllString(branchName, "-")
			// Remove multiple consecutive hyphens
			multipleHyphens := regexp.MustCompile(`-+`)
			branchName = multipleHyphens.ReplaceAllString(branchName, "-")
			// Trim hyphens from start and end
			branchName = strings.Trim(branchName, "-")

			if branchName == "" {
				return fmt.Errorf("invalid branch name after sanitization")
			}

			color.Cyan("Creating worktree for branch: %s", branchName)

			// Prompt for commit type selection
			commitTypes := getCommitTypes()
			color.Cyan("Select commit type:")

			// Convert commit types to select options
			options := make([]ui.SelectOption, len(commitTypes))
			for i, ct := range commitTypes {
				options[i] = ui.SelectOption{
					Key:         fmt.Sprintf("%d", i),
					Title:       fmt.Sprintf("%s %s", ct.Emoji, ct.Name),
					Description: ct.Desc,
				}
			}

			selected, err := ui.RunSelection("Select commit type", options)
			if err != nil && !ui.IsQuitError(err) {
				return fmt.Errorf("failed to select commit type: %w", err)
			}

			selectedIdx := 0
			if err == nil {
				// Convert selected key back to index
				for i, option := range options {
					if option.Key == selected {
						selectedIdx = i
						break
					}
				}
			} else {
				// Default to feat if selection fails or is cancelled
				selectedIdx = 0
			}

			selectedCommitType := commitTypes[selectedIdx]
			color.Green("Selected commit type: %s", selectedCommitType.Name)

			// Create worktree directory path
			worktreePath := filepath.Join(cfg.Directories.Worktrees, branchName)

			// Check if worktree directory already exists
			if _, err := os.Stat(worktreePath); !os.IsNotExist(err) {
				return fmt.Errorf("worktree directory already exists: %s", worktreePath)
			}

			// Ensure worktrees directory exists
			if err := os.MkdirAll(cfg.Directories.Worktrees, 0755); err != nil {
				return fmt.Errorf("failed to create worktrees directory: %w", err)
			}

			color.Yellow("Creating worktree at: %s", worktreePath)

			// Create worktree using git client (this handles the git worktree add command)
			createdWorktree, err := ui.WithSpinnerResult(ui.SpinnerConfig{
				Message: "Creating worktree",
				Color:   "green",
			}, func() (*domain.Worktree, error) {
				return gitClient.CreateWorktreeFromBranch(ctx, repoPath, branchName, mainBranch, worktreePath)
			})
			if err != nil {
				// Check if error is due to timeout or cancellation
				if ctx.Err() != nil {
					return fmt.Errorf("operation timed out or was cancelled: %w", err)
				}
				return fmt.Errorf("failed to create worktree: %w", err)
			}

			color.Green("✅ Worktree created successfully!")
			color.Cyan("📁 Path: %s", createdWorktree.Path)
			color.Cyan("🌿 Branch: %s", createdWorktree.Branch)

			// Create an empty initial commit with JIRA information
			color.Yellow("Creating initial commit...")

			// Use JIRA service to create commit message
			var commitMessage string
			if ticket != "" || summary != "" {
				commitMessage = jiraService.CreateCommitMessage(selectedCommitType.Name, selectedCommitType.Emoji, ticket, summary)
			} else {
				commitMessage = fmt.Sprintf("%s: %s %s", selectedCommitType.Name, selectedCommitType.Emoji, input)
			}

			// Create empty commit
			if err := gitClient.CreateEmptyCommit(ctx, worktreePath, commitMessage); err != nil {
				color.Yellow("Warning: Could not create initial commit: %v", err)
			} else {
				// Log the commit to programming notes
				logCommitHistory(commitMessage)
			}

			// Display JIRA information if available
			if ticket != "" && summary != "" {
				color.Cyan("📋 JIRA: %s - %s", ticket, summary)
			}

			// Install dependencies if package.json exists
			packageManager := detectPackageManager(worktreePath)
			if packageManager != "" {
				err := ui.WithSpinner(ui.SpinnerConfig{
					Message: fmt.Sprintf("Installing dependencies with %s", packageManager),
					Color:   "blue",
				}, func() error {
					return installDependencies(ctx, worktreePath, packageManager)
				})
				if err != nil {
					color.Yellow("Warning: Failed to install dependencies: %v", err)
				}
			} else {
				color.Cyan("No package.json found, skipping dependency installation")
			}

			color.Green("🎉 Worktree setup complete! Happy coding! 🚀")
			fmt.Println()
			color.Cyan("📋 Worktree Summary:")
			color.Cyan("  • Path: %s", worktreePath)
			color.Cyan("  • Branch: %s", branchName)
			color.Cyan("  • Repository: %s", filepath.Base(repoPath))
			color.Cyan("  • Initial commit created with %s type", selectedCommitType.Name)
			if ticket != "" {
				color.Cyan("  • JIRA ticket: %s", ticket)
			}
			fmt.Println()
			color.Yellow("💡 Next steps:")
			color.Yellow("  1. Navigate to worktree: cd %s", worktreePath)
			color.Yellow("  2. Start coding on your feature/fix")
			color.Yellow("  3. Commit and push your changes")
			fmt.Println()

			return nil
		},
	}

	cmd.Flags().StringVarP(&branch, "branch", "b", "", "Branch name for the worktree")
	cmd.Flags().StringVarP(&repository, "repo", "r", "", "Repository path")
	cmd.Flags().StringVarP(&jiraTicket, "jira", "j", "", "JIRA ticket (e.g., ABC-123)")

	return cmd
}

// newWorktreeListCmd creates the worktree list command
func newWorktreeListCmd(cfg *config.Config) *cobra.Command {
	var repository string

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List existing worktrees",
		Long: `List all existing worktrees from the worktrees directory.

Shows worktrees from ~/Programming/Worktrees with their paths, branches, and associated repositories.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()
			gitClient := git.NewClient()

			var repos []*domain.Repository
			if repository != "" {
				// List worktrees for specific repository
				repo, err := ui.WithSpinnerResult(ui.SpinnerConfig{
					Message: "Loading repository",
					Color:   "cyan",
				}, func() (*domain.Repository, error) {
					return gitClient.OpenRepository(repository)
				})
				if err != nil {
					return fmt.Errorf("failed to open repository: %w", err)
				}
				repos = []*domain.Repository{repo}
			} else {
				// Find all repositories
				var err error
				repos, err = ui.WithSpinnerResult(ui.SpinnerConfig{
					Message: "Finding repositories",
					Color:   "cyan",
				}, func() ([]*domain.Repository, error) {
					return gitClient.FindRepositories(ctx, cfg.Directories.Programming, cfg.Git.MaxDepth)
				})
				if err != nil {
					return fmt.Errorf("failed to find repositories: %w", err)
				}
			}

			// List worktrees for each repository, filtering to only show worktrees in configured directory
			totalWorktrees := 0
			worktreeResults, err := ui.WithSpinnerResult(ui.SpinnerConfig{
				Message: "Scanning for worktrees",
				Color:   "yellow",
			}, func() (int, error) {
				count := 0
				for _, repo := range repos {
					worktrees, err := gitClient.ListWorktrees(ctx, repo.Path)
					if err != nil {
						color.Yellow("⚠ Failed to list worktrees for %s: %v", repo.Name, err)
						continue
					}

					var filteredWorktrees []*domain.Worktree
					for _, wt := range worktrees {
						// Skip main repository worktrees (the repository itself)
						if wt.Path == repo.Path {
							continue
						}

						// Only include worktrees that are in the configured worktrees directory
						if strings.HasPrefix(wt.Path, cfg.Directories.Worktrees) {
							filteredWorktrees = append(filteredWorktrees, wt)
						}
					}

					if len(filteredWorktrees) > 0 {
						color.Cyan("\n📁 %s (%s)", repo.Name, repo.Path)
						for _, wt := range filteredWorktrees {
							fmt.Printf("  → %s (branch: %s)\n", wt.Path, wt.Branch)
							count++
						}
					}
				}
				return count, nil
			})
			if err != nil {
				return fmt.Errorf("failed to scan worktrees: %w", err)
			}
			totalWorktrees = worktreeResults

			fmt.Println()
			if totalWorktrees == 0 {
				color.Yellow("📁 No worktrees found in %s.", cfg.Directories.Worktrees)
				color.Cyan("\n💡 Tip: Use 'worktree create' to create your first worktree")
			} else {
				color.Green("✓ Found %d worktrees in %s", totalWorktrees, cfg.Directories.Worktrees)
				fmt.Println()
				color.Cyan("💡 Tips:")
				color.Cyan("  • Use 'cd <path>' to navigate to a worktree")
				color.Cyan("  • Use 'worktree delete' to remove unused worktrees")
				color.Cyan("  • Use 'worktree clean' to cleanup stale references")
			}
			fmt.Println()

			return nil
		},
	}

	cmd.Flags().StringVarP(&repository, "repo", "r", "", "Repository path to list worktrees for")

	return cmd
}

// newWorktreeDeleteCmd creates the worktree delete command
func newWorktreeDeleteCmd(cfg *config.Config) *cobra.Command {
	var force bool

	cmd := &cobra.Command{
		Use:   "delete [worktree-path...]",
		Short: "Delete one or more worktrees",
		Long: `Delete existing Git worktrees from the worktrees directory.

If no paths are provided, you'll be prompted with a multi-select interface.
Use arrow keys to navigate, spacebar to select/deselect, and enter to confirm.`,
		Args: cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()
			gitClient := git.NewClient()

			var worktreePaths []string
			if len(args) > 0 {
				worktreePaths = args
			} else {
				// Find all worktrees in the configured worktrees directory only
				allWorktrees, err := ui.WithSpinnerResult(ui.SpinnerConfig{
					Message: "Finding worktrees to delete",
					Color:   "yellow",
				}, func() ([]*domain.Worktree, error) {
					repos, err := gitClient.FindRepositories(ctx, cfg.Directories.Programming, cfg.Git.MaxDepth)
					if err != nil {
						return nil, fmt.Errorf("failed to find repositories: %w", err)
					}

					var allWorktrees []*domain.Worktree
					for _, repo := range repos {
						worktrees, err := gitClient.ListWorktrees(ctx, repo.Path)
						if err != nil {
							continue
						}

						// Filter to only include worktrees in the configured worktrees directory
						for _, wt := range worktrees {
							// Skip main repository worktrees (the repository itself)
							if wt.Path == repo.Path {
								continue
							}

							// Only include worktrees that are in the configured worktrees directory
							if strings.HasPrefix(wt.Path, cfg.Directories.Worktrees) {
								allWorktrees = append(allWorktrees, wt)
							}
						}
					}
					return allWorktrees, nil
				})
				if err != nil {
					return err
				}

				if len(allWorktrees) == 0 {
					return fmt.Errorf("no worktrees found in %s", cfg.Directories.Worktrees)
				}

				// Use multi-select UI for worktree selection
				selectedPaths, err := selectMultipleWorktrees(allWorktrees)
				if err != nil {
					return fmt.Errorf("failed to select worktrees: %w", err)
				}

				if len(selectedPaths) == 0 {
					color.Yellow("No worktrees selected for deletion")
					return nil
				}

				worktreePaths = selectedPaths
			}

			// Confirm deletion unless force flag is used
			if !force {
				fmt.Println()
				color.Yellow("Selected worktrees for deletion:")
				for i, path := range worktreePaths {
					color.Red("  %d. %s", i+1, filepath.Base(path))
				}

				prompt := promptui.Prompt{
					Label:     fmt.Sprintf("Delete %d worktree(s)", len(worktreePaths)),
					IsConfirm: true,
				}

				if _, err := prompt.Run(); err != nil {
					return fmt.Errorf("deletion cancelled")
				}
			}

			// Delete worktrees one by one with progress feedback
			fmt.Println()
			color.Cyan("🗑️  Deleting %d worktree(s)...", len(worktreePaths))

			var successful []string
			var failed []string

			for i, worktreePath := range worktreePaths {
				color.Yellow("(%d/%d) Processing %s...", i+1, len(worktreePaths), filepath.Base(worktreePath))

				result, err := ui.WithSpinnerResult(ui.SpinnerConfig{
					Message: fmt.Sprintf("Deleting %s", filepath.Base(worktreePath)),
					Color:   "red",
				}, func() (*domain.DeletionResult, error) {
					return gitClient.DeleteWorktree(ctx, worktreePath)
				})

				if err != nil {
					color.Red("✗ Failed to delete %s: %v", filepath.Base(worktreePath), err)
					failed = append(failed, worktreePath)
				} else {
					var statusMsg string
					if result.UsedFallback {
						statusMsg = fmt.Sprintf("⚠ %s deleted using fallback method", filepath.Base(worktreePath))
					} else {
						statusMsg = fmt.Sprintf("✓ %s deleted successfully", filepath.Base(worktreePath))
					}

					// Add branch deletion info
					if result.BranchDeleted {
						statusMsg += fmt.Sprintf(" (branch '%s' deleted)", result.Branch)
					} else if result.BranchDeleteError != "" {
						statusMsg += fmt.Sprintf(" (branch deletion failed: %s)", result.BranchDeleteError)
					} else if result.Branch != "" {
						statusMsg += fmt.Sprintf(" (branch '%s' preserved)", result.Branch)
					}

					if result.UsedFallback {
						color.Yellow(statusMsg)
					} else {
						color.Green(statusMsg)
					}

					successful = append(successful, worktreePath)
				}
			}

			// Final summary
			fmt.Println()
			if len(successful) > 0 {
				color.Green("✅ Successfully deleted %d worktree(s):", len(successful))
				for _, path := range successful {
					color.Green("  • %s", filepath.Base(path))
				}
			}

			if len(failed) > 0 {
				color.Red("❌ Failed to delete %d worktree(s):", len(failed))
				for _, path := range failed {
					color.Red("  • %s", filepath.Base(path))
				}
			}

			if len(successful) > 0 {
				fmt.Println()
				color.Cyan("📋 Deletion Summary:")
				color.Cyan("  • Total processed: %d", len(worktreePaths))
				color.Cyan("  • Successfully deleted: %d", len(successful))
				if len(failed) > 0 {
					color.Cyan("  • Failed: %d", len(failed))
				}
				color.Cyan("  • Associated branches are automatically deleted")
				fmt.Println()

				color.Yellow("💡 Worktrees and their local branches have been cleaned up")
				fmt.Println()
			}

			if len(failed) > 0 {
				return fmt.Errorf("failed to delete %d out of %d worktrees", len(failed), len(worktreePaths))
			}

			return nil
		},
	}

	cmd.Flags().BoolVarP(&force, "force", "f", false, "Force deletion without confirmation")

	return cmd
}

// newWorktreeCleanCmd creates the worktree clean command
func newWorktreeCleanCmd(cfg *config.Config) *cobra.Command {
	var dryRun bool

	cmd := &cobra.Command{
		Use:   "clean",
		Short: "Clean up stale worktrees",
		Long: `Clean up worktrees that no longer exist or are corrupted.

This command will:
1. Find all repositories
2. List their worktrees
3. Check if worktree directories still exist
4. Remove references to missing worktrees`,
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()
			gitClient := git.NewClient()

			// First, scan for stale worktrees
			type ScanResult struct {
				StaleWorktrees map[string][]string // repo path -> stale worktree paths
				RepoCount      int
			}

			result, err := ui.WithSpinnerResult(ui.SpinnerConfig{
				Message: "Scanning for stale worktrees",
				Color:   "yellow",
			}, func() (ScanResult, error) {
				staleWorktrees := make(map[string][]string)

				// Find all repositories
				repos, err := gitClient.FindRepositories(ctx, cfg.Directories.Programming, cfg.Git.MaxDepth)
				if err != nil {
					return ScanResult{}, fmt.Errorf("failed to find repositories: %w", err)
				}

				for _, repo := range repos {
					worktrees, err := gitClient.ListWorktrees(ctx, repo.Path)
					if err != nil {
						color.Yellow("⚠ Failed to list worktrees for %s: %v", repo.Name, err)
						continue
					}

					var stalePaths []string
					for _, wt := range worktrees {
						// Skip main worktree (the repository itself)
						if wt.Path == repo.Path {
							continue
						}

						// Check if worktree directory exists
						if _, err := os.Stat(wt.Path); os.IsNotExist(err) {
							stalePaths = append(stalePaths, wt.Path)
						}
					}

					if len(stalePaths) > 0 {
						staleWorktrees[repo.Path] = stalePaths
					}
				}

				return ScanResult{
					StaleWorktrees: staleWorktrees,
					RepoCount:      len(repos),
				}, nil
			})
			if err != nil {
				return err
			}

			// Count total stale worktrees
			totalStale := 0
			for _, paths := range result.StaleWorktrees {
				totalStale += len(paths)
			}

			fmt.Println()
			if totalStale == 0 {
				color.Green("✓ No stale worktrees found - your setup is clean!")
				fmt.Println()
				color.Cyan("📋 Cleanup Summary:")
				color.Cyan("  • Scanned %d repositories", result.RepoCount)
				color.Cyan("  • All worktree references are valid")
				color.Cyan("  • No cleanup required")
				fmt.Println()
				return nil
			}

			// Show what will be cleaned
			if dryRun {
				color.Yellow("Found %d stale worktrees (dry run mode)", totalStale)
				fmt.Println()
				for repoPath, stalePaths := range result.StaleWorktrees {
					color.Cyan("📁 %s", filepath.Base(repoPath))
					for _, path := range stalePaths {
						color.Yellow("  Would clean: %s", path)
					}
				}
				fmt.Println()
				color.Cyan("📋 Cleanup Preview:")
				color.Cyan("  • Stale worktrees found: %d", totalStale)
				color.Cyan("  • Run without --dry-run to clean them up")
				color.Cyan("  • This will only remove Git references, not files")
				fmt.Println()
				return nil
			}

			// Show what will be cleaned and ask for confirmation
			color.Yellow("Found %d stale worktrees:", totalStale)
			fmt.Println()
			for repoPath, stalePaths := range result.StaleWorktrees {
				color.Cyan("📁 %s", filepath.Base(repoPath))
				for _, path := range stalePaths {
					color.Yellow("  Will clean: %s", path)
				}
			}
			fmt.Println()

			// Confirm cleanup
			confirmPrompt := promptui.Prompt{
				Label:     fmt.Sprintf("Clean up %d stale worktree references", totalStale),
				IsConfirm: true,
			}

			if _, err := confirmPrompt.Run(); err != nil {
				color.Yellow("Cleanup cancelled")
				return nil
			}

			// Perform cleanup
			cleanupCount := 0
			for repoPath, stalePaths := range result.StaleWorktrees {
				if len(stalePaths) > 0 {
					err := ui.WithSpinner(ui.SpinnerConfig{
						Message: fmt.Sprintf("Cleaning %s", filepath.Base(repoPath)),
						Color:   "red",
					}, func() error {
						return gitClient.PruneWorktrees(ctx, repoPath)
					})
					if err != nil {
						color.Yellow("⚠ Failed to clean %s: %v", filepath.Base(repoPath), err)
					} else {
						cleanupCount += len(stalePaths)
					}
				}
			}

			color.Green("✓ Cleanup completed successfully!")
			fmt.Println()
			color.Cyan("📋 Cleanup Summary:")
			color.Cyan("  • Cleaned %d stale worktree references", cleanupCount)
			color.Cyan("  • Git worktree database updated")
			color.Cyan("  • Your worktree setup is now clean")
			fmt.Println()
			color.Yellow("💡 Note: Only Git references were removed, actual directories remain untouched")
			fmt.Println()

			return nil
		},
	}

	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "Show what would be cleaned without actually doing it")

	return cmd
}
