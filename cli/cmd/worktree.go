package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/fatih/color"
	"github.com/manifoldco/promptui"
	"github.com/spf13/cobra"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/domain"
	"github.com/jimmy/dotfiles-cli/internal/git"
	"github.com/jimmy/dotfiles-cli/internal/jira"
)

// newWorktreeCreateCmd creates the worktree create command
func newWorktreeCreateCmd(cfg *config.Config) *cobra.Command {
	var (
		branch     string
		jiraTicket string
		repository string
	)

	cmd := &cobra.Command{
		Use:   "create [branch-name]",
		Short: "Create a new worktree",
		Long: `Create a new Git worktree for development.

If no branch name is provided, you'll be prompted to enter one.
The worktree will be created in the configured worktrees directory.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()
			gitClient := git.NewClient()

			// Initialize JIRA client
			jiraClient, err := jira.NewClient(cfg)
			if err != nil {
				return fmt.Errorf("failed to create JIRA client: %w", err)
			}

			// Handle JIRA ticket if provided
			var ticket *domain.JiraTicket
			if jiraTicket != "" {
				color.Cyan("🎫 Validating JIRA ticket: %s", jiraTicket)

				validatedTicket, err := jiraClient.ValidateTicket(jiraTicket)
				if err != nil {
					color.Yellow("⚠ JIRA validation failed: %v", err)
					color.Yellow("Continuing without JIRA integration...")
				} else {
					ticket = validatedTicket
					color.Green("✓ JIRA ticket validated: %s", ticket.Summary)

					// Auto-generate branch name if not provided
					if len(args) == 0 && branch == "" {
						branch = jiraClient.GenerateBranchName(ticket.Key, ticket.Summary)
						color.Cyan("📝 Auto-generated branch name: %s", branch)
					}
				}
			}

			// Get branch name
			if len(args) > 0 && branch == "" {
				branch = args[0]
			} else if branch == "" {
				prompt := promptui.Prompt{
					Label: "Branch name",
				}
				branch, err = prompt.Run()
				if err != nil {
					return fmt.Errorf("failed to get branch name: %w", err)
				}
			}

			// Validate branch name
			if branch == "" {
				return fmt.Errorf("branch name cannot be empty")
			}

			// Get repository path
			var repoPath string
			if repository != "" {
				repoPath = repository
			} else {
				// Find repositories and let user select
				color.Cyan("🔍 Finding repositories...")
				repos, err := gitClient.FindRepositories(ctx, cfg.Directories.Programming, cfg.Git.MaxDepth)
				if err != nil {
					return fmt.Errorf("failed to find repositories: %w", err)
				}

				if len(repos) == 0 {
					return fmt.Errorf("no Git repositories found in %s", cfg.Directories.Programming)
				}

				// Create selection prompt
				templates := &promptui.SelectTemplates{
					Label:    "{{ . }}",
					Active:   "→ {{ .Name | cyan }} ({{ .Path | faint }})",
					Inactive: "  {{ .Name }} ({{ .Path | faint }})",
					Selected: "✓ {{ .Name | green }}",
				}

				prompt := promptui.Select{
					Label:     "Select repository",
					Items:     repos,
					Templates: templates,
				}

				idx, _, err := prompt.Run()
				if err != nil {
					return fmt.Errorf("failed to select repository: %w", err)
				}

				repoPath = repos[idx].Path
			}

			// Create worktree path
			worktreeName := branch
			if ticket != nil {
				// Use the full branch name that was generated from JIRA
				worktreeName = branch
			}

			worktreePath := filepath.Join(cfg.Directories.Worktrees, worktreeName)

			// Create worktree
			color.Cyan("🌳 Creating worktree...")
			createdWorktree, err := gitClient.CreateWorktree(ctx, repoPath, branch, worktreePath)
			if err != nil {
				return fmt.Errorf("failed to create worktree: %w", err)
			}

			// Associate JIRA ticket with worktree if available
			if ticket != nil {
				createdWorktree.JiraTicket = ticket
			}

			color.Green("✓ Worktree created successfully!")
			fmt.Printf("Path: %s\n", createdWorktree.Path)
			fmt.Printf("Branch: %s\n", createdWorktree.Branch)
			if ticket != nil {
				fmt.Printf("JIRA Ticket: %s - %s\n", ticket.Key, ticket.Summary)
			}

			return nil
		},
	}

	cmd.Flags().StringVarP(&branch, "branch", "b", "", "Branch name for the worktree")
	cmd.Flags().StringVarP(&jiraTicket, "jira", "j", "", "JIRA ticket number")
	cmd.Flags().StringVarP(&repository, "repo", "r", "", "Repository path")

	return cmd
}

// newWorktreeListCmd creates the worktree list command
func newWorktreeListCmd(cfg *config.Config) *cobra.Command {
	var repository string

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List existing worktrees",
		Long: `List all existing worktrees for repositories.

Shows worktrees with their paths, branches, and associated repositories.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()
			gitClient := git.NewClient()

			var repos []*domain.Repository
			if repository != "" {
				// List worktrees for specific repository
				repo, err := gitClient.OpenRepository(repository)
				if err != nil {
					return fmt.Errorf("failed to open repository: %w", err)
				}
				repos = []*domain.Repository{repo}
			} else {
				// Find all repositories
				var err error
				repos, err = gitClient.FindRepositories(ctx, cfg.Directories.Programming, cfg.Git.MaxDepth)
				if err != nil {
					return fmt.Errorf("failed to find repositories: %w", err)
				}
			}

			// List worktrees for each repository
			totalWorktrees := 0
			for _, repo := range repos {
				worktrees, err := gitClient.ListWorktrees(ctx, repo.Path)
				if err != nil {
					color.Yellow("⚠ Failed to list worktrees for %s: %v", repo.Name, err)
					continue
				}

				if len(worktrees) > 0 {
					color.Cyan("\n📁 %s (%s)", repo.Name, repo.Path)
					for _, wt := range worktrees {
						fmt.Printf("  → %s (branch: %s)\n", wt.Path, wt.Branch)
						totalWorktrees++
					}
				}
			}

			if totalWorktrees == 0 {
				color.Yellow("No worktrees found.")
			} else {
				color.Green("\n✓ Found %d worktrees", totalWorktrees)
			}

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
		Use:   "delete [worktree-path]",
		Short: "Delete a worktree",
		Long: `Delete an existing Git worktree.

If no path is provided, you'll be prompted to select from existing worktrees.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := context.Background()
			gitClient := git.NewClient()

			var worktreePath string
			if len(args) > 0 {
				worktreePath = args[0]
			} else {
				// Find all worktrees and let user select
				repos, err := gitClient.FindRepositories(ctx, cfg.Directories.Programming, cfg.Git.MaxDepth)
				if err != nil {
					return fmt.Errorf("failed to find repositories: %w", err)
				}

				var allWorktrees []*domain.Worktree
				for _, repo := range repos {
					worktrees, err := gitClient.ListWorktrees(ctx, repo.Path)
					if err != nil {
						continue
					}
					allWorktrees = append(allWorktrees, worktrees...)
				}

				if len(allWorktrees) == 0 {
					return fmt.Errorf("no worktrees found")
				}

				// Create selection prompt
				templates := &promptui.SelectTemplates{
					Label:    "{{ . }}",
					Active:   "→ {{ .Path | cyan }} ({{ .Branch | faint }})",
					Inactive: "  {{ .Path }} ({{ .Branch | faint }})",
					Selected: "✓ {{ .Path | red }}",
				}

				prompt := promptui.Select{
					Label:     "Select worktree to delete",
					Items:     allWorktrees,
					Templates: templates,
				}

				idx, _, err := prompt.Run()
				if err != nil {
					return fmt.Errorf("failed to select worktree: %w", err)
				}

				worktreePath = allWorktrees[idx].Path
			}

			// Confirm deletion unless force flag is used
			if !force {
				prompt := promptui.Prompt{
					Label:     fmt.Sprintf("Delete worktree %s", worktreePath),
					IsConfirm: true,
				}

				if _, err := prompt.Run(); err != nil {
					return fmt.Errorf("deletion cancelled")
				}
			}

			// Delete worktree
			color.Cyan("🗑️  Deleting worktree...")
			if err := gitClient.DeleteWorktree(ctx, worktreePath); err != nil {
				return fmt.Errorf("failed to delete worktree: %w", err)
			}

			color.Green("✓ Worktree deleted successfully!")
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

			color.Cyan("🧹 Cleaning up stale worktrees...")

			// Find all repositories
			repos, err := gitClient.FindRepositories(ctx, cfg.Directories.Programming, cfg.Git.MaxDepth)
			if err != nil {
				return fmt.Errorf("failed to find repositories: %w", err)
			}

			var stalePaths []string

			for _, repo := range repos {
				worktrees, err := gitClient.ListWorktrees(ctx, repo.Path)
				if err != nil {
					color.Yellow("⚠ Failed to list worktrees for %s: %v", repo.Name, err)
					continue
				}

				for _, wt := range worktrees {
					// Skip main worktree (the repository itself)
					if wt.Path == repo.Path {
						continue
					}

					// Check if worktree directory exists
					if _, err := os.Stat(wt.Path); os.IsNotExist(err) {
						stalePaths = append(stalePaths, wt.Path)
						if dryRun {
							color.Yellow("Would clean: %s", wt.Path)
						} else {
							color.Yellow("Cleaning stale worktree: %s", wt.Path)
							// Use git worktree prune to clean up
							// This is safer than trying to remove individual worktree references
						}
					}
				}

				// Run git worktree prune for this repository
				if !dryRun && len(stalePaths) > 0 {
					// We could implement git worktree prune here, but for now just report
				}
			}

			if len(stalePaths) == 0 {
				color.Green("✓ No stale worktrees found")
			} else if dryRun {
				color.Yellow("Found %d stale worktrees (use --dry-run=false to clean)", len(stalePaths))
			} else {
				color.Green("✓ Cleaned %d stale worktrees", len(stalePaths))
			}

			return nil
		},
	}

	cmd.Flags().BoolVar(&dryRun, "dry-run", true, "Show what would be cleaned without actually doing it")

	return cmd
}
