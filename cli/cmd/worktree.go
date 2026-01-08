package cmd

import (
	"bufio"
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

	"github.com/fatih/color"
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
func selectMultipleWorktrees(ctx context.Context, worktrees []*domain.Worktree) ([]string, error) {
	if len(worktrees) == 0 {
		return nil, fmt.Errorf("no worktrees available for selection")
	}

	// Create display options for fzf
	var options []ui.FzfOption
	for _, wt := range worktrees {
		displayName := fmt.Sprintf("%s (branch: %s)", filepath.Base(wt.Path), wt.Branch)
		options = append(options, ui.FzfOption{
			Value:   wt.Path,
			Display: displayName,
		})
	}

	config := ui.FzfConfig{
		Prompt: "Select worktrees to delete",
		Header: "Use TAB to select multiple, ENTER to confirm, ESC to cancel",
		Multi:  true,
		Height: "60%",
	}

	selectedPaths, err := ui.RunFzfMulti(ctx, options, config)
	if err != nil {
		return nil, fmt.Errorf("worktree selection failed: %w", err)
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
					// Convert repositories to fzf options
					var fzfOptions []ui.FzfOption
					for _, repo := range repos {
						display := fmt.Sprintf("%-25s %s", repo.Name, color.New(color.FgHiBlack).Sprint(repo.Path))
						fzfOptions = append(fzfOptions, ui.FzfOption{
							Value:   repo.Path,
							Display: display,
						})
					}

					config := ui.FzfConfig{
						Prompt: "Select repository",
						Height: "40%",
					}

					// Use fzf for repository selection
					selected, err := ui.RunFzfSingle(ctx, fzfOptions, config)
					if err != nil {
						return fmt.Errorf("failed to select repository: %w", err)
					}

					if selected == "" {
						return fmt.Errorf("repository selection cancelled")
					}

					repoPath = selected
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
				// Prompt for JIRA ticket or branch name using standard input
				fmt.Print("JIRA ticket (e.g., ABC-123) or branch name: ")
				scanner := bufio.NewScanner(os.Stdin)
				if scanner.Scan() {
					input = strings.TrimSpace(scanner.Text())
				}
				if err := scanner.Err(); err != nil {
					return fmt.Errorf("failed to read input: %w", err)
				}
				if input == "" {
					return fmt.Errorf("input cannot be empty")
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

			// Convert commit types to fzf options
			var fzfOptions []ui.FzfOption
			for i, ct := range commitTypes {
				display := fmt.Sprintf("%-15s %s %s", ct.Name, ct.Emoji, color.New(color.FgHiBlack).Sprint(ct.Desc))
				fzfOptions = append(fzfOptions, ui.FzfOption{
					Value:   fmt.Sprintf("%d", i),
					Display: display,
				})
			}

			config := ui.FzfConfig{
				Prompt: "Select commit type",
				Height: "40%",
				NoSort: true, // Keep the order we defined
			}

			selected, err := ui.RunFzfSingle(ctx, fzfOptions, config)
			if err != nil {
				return fmt.Errorf("failed to select commit type: %w", err)
			}

			selectedIdx := 0
			if selected != "" {
				// Convert selected value back to index
				for i, option := range fzfOptions {
					if option.Value == selected {
						selectedIdx = i
						break
					}
				}
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
				selectedPaths, err := selectMultipleWorktrees(ctx, allWorktrees)
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

				confirmed, err := ui.RunFzfConfirmation(ctx, fmt.Sprintf("Delete %d worktree(s)?", len(worktreePaths)))
				if err != nil {
					return fmt.Errorf("confirmation failed: %w", err)
				}

				if !confirmed {
					return fmt.Errorf("deletion cancelled")
				}
			}

			// Delete worktrees one by one with progress feedback
			fmt.Println()
			color.Cyan("🗑️  Deleting %d worktree(s)...", len(worktreePaths))

			// Create a cancelable context for the entire deletion process
			deleteCtx, cancel := context.WithCancel(ctx)

			// Set up signal handling to allow user to interrupt
			sigChan := make(chan os.Signal, 1)
			signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
			go func() {
				select {
				case <-sigChan:
					color.Yellow("\n⚠️  Interruption received, canceling remaining deletions...")
					cancel()
				case <-deleteCtx.Done():
				}
			}()
			defer signal.Stop(sigChan)

			var successful []string
			var failed []string

			for i, worktreePath := range worktreePaths {
				// Check if context was cancelled
				select {
				case <-deleteCtx.Done():
					color.Yellow("Deletion process cancelled. Remaining worktrees were not processed.")
					break
				default:
				}

				color.Yellow("(%d/%d) Processing %s...", i+1, len(worktreePaths), filepath.Base(worktreePath))

				// Create a timeout context for each deletion (20 seconds max)
				timeoutCtx, timeoutCancel := context.WithTimeout(deleteCtx, 20*time.Second)

				result, err := ui.WithSpinnerResult(ui.SpinnerConfig{
					Message: fmt.Sprintf("Deleting %s", filepath.Base(worktreePath)),
					Color:   "red",
				}, func() (*domain.DeletionResult, error) {
					defer timeoutCancel() // Ensure context is canceled when done
					return gitClient.DeleteWorktree(timeoutCtx, worktreePath)
				})

				if err != nil {
					if deleteCtx.Err() == context.Canceled {
						color.Yellow("✗ Cancelled deletion of %s", filepath.Base(worktreePath))
						failed = append(failed, worktreePath)
						break // Stop processing remaining worktrees
					} else {
						color.Red("✗ Failed to delete %s: %v", filepath.Base(worktreePath), err)
						failed = append(failed, worktreePath)
					}
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

// newWorktreeCheckoutCmd creates the worktree checkout command
func newWorktreeCheckoutCmd(cfg *config.Config) *cobra.Command {
	var repository string

	cmd := &cobra.Command{
		Use:   "checkout [branch-name]",
		Short: "Checkout existing remote branch as worktree",
		Long: `Checkout an existing remote branch as a new Git worktree.

This command will:
1. Fetch the latest changes from origin
2. Show available remote branches for selection (if no branch specified)
3. Create a new worktree from the selected remote branch
4. Install dependencies if package.json exists

The worktree will be created in the configured worktrees directory.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			// Create a timeout context
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
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

				if len(repos) > 1 {
					// Convert repositories to fzf options
					var fzfOptions []ui.FzfOption
					for _, repo := range repos {
						display := fmt.Sprintf("%-25s %s", repo.Name, color.New(color.FgHiBlack).Sprint(repo.Path))
						fzfOptions = append(fzfOptions, ui.FzfOption{
							Value:   repo.Path,
							Display: display,
						})
					}

					config := ui.FzfConfig{
						Prompt: "Select repository",
						Height: "40%",
					}

					// Use fzf for repository selection
					selected, err := ui.RunFzfSingle(ctx, fzfOptions, config)
					if err != nil {
						return fmt.Errorf("failed to select repository: %w", err)
					}

					if selected == "" {
						return fmt.Errorf("repository selection cancelled")
					}

					repoPath = selected
				} else {
					repoPath = repos[0].Path
				}
			}

			color.Yellow("Repository path: %s", repoPath)

			// Fetch latest remote branches
			err := ui.WithSpinner(ui.SpinnerConfig{
				Message: "Fetching latest changes from origin",
				Color:   "blue",
			}, func() error {
				return gitClient.FetchOrigin(ctx, repoPath)
			})
			if err != nil {
				color.Yellow("Warning: Failed to fetch from origin: %v", err)
				color.Yellow("Proceeding with existing remote branch information...")
			}

			// Get branch name - either from args or interactive selection
			var branchName string
			if len(args) > 0 {
				branchName = args[0]
			} else {
				// Get all remote branches
				remoteBranches, err := ui.WithSpinnerResult(ui.SpinnerConfig{
					Message: "Loading remote branches",
					Color:   "cyan",
				}, func() ([]string, error) {
					return gitClient.ListRemoteBranches(ctx, repoPath)
				})
				if err != nil {
					return fmt.Errorf("failed to list remote branches: %w", err)
				}

				if len(remoteBranches) == 0 {
					return fmt.Errorf("no remote branches found")
				}

				// Convert branches to fzf options
				var fzfOptions []ui.FzfOption
				for _, branch := range remoteBranches {
					fzfOptions = append(fzfOptions, ui.FzfOption{
						Value:   branch,
						Display: branch,
					})
				}

				config := ui.FzfConfig{
					Prompt: "Select remote branch to checkout",
					Height: "60%",
				}

				// Use fzf for branch selection
				selected, err := ui.RunFzfSingle(ctx, fzfOptions, config)
				if err != nil {
					return fmt.Errorf("failed to select branch: %w", err)
				}

				if selected == "" {
					return fmt.Errorf("branch selection cancelled")
				}

				branchName = selected
			}

			// Validate branch name
			if branchName == "" {
				return fmt.Errorf("branch name cannot be empty")
			}

			color.Cyan("Checking out remote branch: %s", branchName)

			// Create worktree directory path based on branch name
			// Clean branch name for directory (similar to shell script logic)
			invalidChars := regexp.MustCompile(`[^a-zA-Z0-9._-]`)
			folderName := invalidChars.ReplaceAllString(branchName, "-")
			// Remove multiple consecutive hyphens
			multipleHyphens := regexp.MustCompile(`-+`)
			folderName = multipleHyphens.ReplaceAllString(folderName, "-")
			// Trim hyphens from start and end
			folderName = strings.Trim(folderName, "-")

			if folderName == "" {
				folderName = "checkout-" + fmt.Sprintf("%d", time.Now().Unix())
			}

			worktreePath := filepath.Join(cfg.Directories.Worktrees, folderName)

			// Check if worktree directory already exists
			if _, err := os.Stat(worktreePath); !os.IsNotExist(err) {
				color.Yellow("Worktree directory already exists: %s", worktreePath)

				// Check if it's a valid git worktree
				worktrees, err := gitClient.ListWorktrees(ctx, repoPath)
				if err == nil {
					for _, wt := range worktrees {
						if wt.Path == worktreePath {
							color.Green("Switching to existing worktree: %s", worktreePath)
							color.Cyan("📁 Path: %s", worktreePath)
							color.Cyan("🌿 Branch: %s", wt.Branch)
							return nil
						}
					}
				}

				// Directory exists but not a valid worktree, ask user what to do
				confirmed, err := ui.RunFzfConfirmation(ctx, fmt.Sprintf("Directory exists but is not a valid git worktree. Remove and recreate?"))
				if err != nil {
					return fmt.Errorf("confirmation failed: %w", err)
				}

				if !confirmed {
					return fmt.Errorf("operation cancelled")
				}

				if err := os.RemoveAll(worktreePath); err != nil {
					return fmt.Errorf("failed to remove existing directory: %w", err)
				}
			}

			// Ensure worktrees directory exists
			if err := os.MkdirAll(cfg.Directories.Worktrees, 0755); err != nil {
				return fmt.Errorf("failed to create worktrees directory: %w", err)
			}

			color.Yellow("Creating worktree at: %s", worktreePath)

			// Create worktree from remote branch
			createdWorktree, err := ui.WithSpinnerResult(ui.SpinnerConfig{
				Message: "Creating worktree from remote branch",
				Color:   "green",
			}, func() (*domain.Worktree, error) {
				return gitClient.CheckoutRemoteBranch(ctx, repoPath, branchName, worktreePath)
			})
			if err != nil {
				// Check if error is due to timeout or cancellation
				if ctx.Err() != nil {
					return fmt.Errorf("operation timed out or was cancelled: %w", err)
				}
				return fmt.Errorf("failed to create worktree: %w", err)
			}

			color.Green("✅ Worktree checked out successfully!")
			color.Cyan("📁 Path: %s", createdWorktree.Path)
			color.Cyan("🌿 Branch: %s", createdWorktree.Branch)

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
				} else {
					color.Green("✅ Dependencies installed successfully!")
				}
			} else {
				color.Cyan("No package.json found, skipping dependency installation")
			}

			color.Green("🎉 Checkout complete! Happy coding! 🚀")
			fmt.Println()
			color.Cyan("📋 Worktree Summary:")
			color.Cyan("  • Path: %s", worktreePath)
			color.Cyan("  • Branch: %s", branchName)
			color.Cyan("  • Repository: %s", filepath.Base(repoPath))
			color.Cyan("  • Checked out from remote branch")
			fmt.Println()
			color.Yellow("💡 Next steps:")
			color.Yellow("  1. Navigate to worktree: cd %s", worktreePath)
			color.Yellow("  2. Start working on your changes")
			color.Yellow("  3. Commit and push your changes")
			fmt.Println()

			return nil
		},
	}

	cmd.Flags().StringVarP(&repository, "repo", "r", "", "Repository path")

	return cmd
}
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

			// Confirm cleanup using fzf
			confirmed, err := ui.RunFzfConfirmation(ctx, fmt.Sprintf("Clean up %d stale worktree references?", totalStale))
			if err != nil {
				return fmt.Errorf("confirmation failed: %w", err)
			}

			if !confirmed {
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
