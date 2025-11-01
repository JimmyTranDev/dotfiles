package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"wtm/internal/config"
	"wtm/internal/core"
)

var updateCmd = &cobra.Command{
	Use:   "update [worktree]",
	Short: "Update a git worktree with latest changes from main branch",
	Long:  `Update a git worktree by pulling latest changes from the main branch and rebasing current branch`,
	Args:  cobra.MaximumNArgs(1),
	RunE:  runUpdate,
}

func init() {
	updateCmd.Flags().BoolP("all", "a", false, "Update all worktrees")
	updateCmd.Flags().BoolP("pull-only", "p", false, "Only pull changes, don't rebase")
	updateCmd.Flags().BoolP("rebase", "r", false, "Force rebase even if there are conflicts")
}

func runUpdate(cmd *cobra.Command, args []string) error {
	cfg := config.NewConfig()
	all, _ := cmd.Flags().GetBool("all")
	pullOnly, _ := cmd.Flags().GetBool("pull-only")
	forceRebase, _ := cmd.Flags().GetBool("rebase")

	// Select repository
	repoPath, err := core.SelectRepository(cfg.ProgrammingDir)
	if err != nil {
		return fmt.Errorf("failed to select repository: %w", err)
	}

	// Find main branch
	mainBranch, err := core.FindMainBranch(repoPath)
	if err != nil {
		return fmt.Errorf("failed to find main branch: %w", err)
	}

	if all {
		return updateAllWorktrees(repoPath, mainBranch, pullOnly, forceRebase)
	}

	var worktreeName string
	if len(args) > 0 {
		worktreeName = args[0]
	} else {
		// Get list of worktrees and let user select
		selected, err := selectWorktreeToUpdate(repoPath)
		if err != nil {
			return fmt.Errorf("failed to select worktree: %w", err)
		}
		worktreeName = selected
	}

	return updateWorktree(repoPath, worktreeName, mainBranch, pullOnly, forceRebase)
}

func selectWorktreeToUpdate(repoPath string) (string, error) {
	// Get list of worktrees
	cmd := exec.Command("git", "worktree", "list", "--porcelain")
	cmd.Dir = repoPath
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to list worktrees: %w", err)
	}

	var worktrees []string
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "worktree ") {
			path := strings.TrimPrefix(line, "worktree ")
			// Skip the main worktree (usually the repo root)
			if path != repoPath {
				worktreeName := filepath.Base(path)
				worktrees = append(worktrees, worktreeName)
			}
		}
	}

	if len(worktrees) == 0 {
		return "", fmt.Errorf("no worktrees found to update")
	}

	return core.PromptForChoice("Select worktree to update:", worktrees)
}

func updateWorktree(repoPath, worktreeName, mainBranch string, pullOnly, forceRebase bool) error {
	worktreePath := filepath.Join(repoPath, worktreeName)

	// Check if worktree exists
	if _, err := os.Stat(worktreePath); os.IsNotExist(err) {
		return fmt.Errorf("worktree '%s' does not exist", worktreeName)
	}

	core.PrintColorf(core.ColorCyan, "Updating worktree '%s'...", worktreeName)

	// First, update the main branch in the main repository
	core.PrintColor(core.ColorYellow, "Updating main branch...")
	cmd := exec.Command("git", "checkout", mainBranch)
	cmd.Dir = repoPath
	if err := cmd.Run(); err != nil {
		core.PrintColorf(core.ColorRed, "Warning: failed to checkout main branch in main repo: %v", err)
	}

	cmd = exec.Command("git", "pull", "origin", mainBranch)
	cmd.Dir = repoPath
	if err := cmd.Run(); err != nil {
		core.PrintColorf(core.ColorRed, "Warning: failed to pull main branch: %v", err)
	}

	// Get current branch in worktree
	cmd = exec.Command("git", "branch", "--show-current")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get current branch: %w", err)
	}
	currentBranch := strings.TrimSpace(string(output))

	// Check for uncommitted changes
	cmd = exec.Command("git", "status", "--porcelain")
	cmd.Dir = worktreePath
	output, err = cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to check git status: %w", err)
	}

	hasUncommittedChanges := len(strings.TrimSpace(string(output))) > 0
	if hasUncommittedChanges {
		core.PrintColorf(core.ColorYellow, "Worktree has uncommitted changes. Stashing...")
		cmd = exec.Command("git", "stash", "push", "-m", "wtm-update-stash")
		cmd.Dir = worktreePath
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to stash changes: %w", err)
		}
		defer func() {
			// Try to pop stash after update
			cmd := exec.Command("git", "stash", "pop")
			cmd.Dir = worktreePath
			if err := cmd.Run(); err != nil {
				core.PrintColorf(core.ColorYellow, "Warning: failed to restore stash: %v", err)
				core.PrintColor(core.ColorYellow, "You may need to manually apply stashed changes with 'git stash pop'")
			}
		}()
	}

	// If we're on main branch, just pull
	if currentBranch == mainBranch {
		core.PrintColorf(core.ColorYellow, "Pulling latest changes on %s branch...", mainBranch)
		cmd = exec.Command("git", "pull", "origin", mainBranch)
		cmd.Dir = worktreePath
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	}

	// Pull latest changes to current branch
	core.PrintColorf(core.ColorYellow, "Pulling latest changes for branch '%s'...", currentBranch)
	cmd = exec.Command("git", "pull", "origin", currentBranch)
	cmd.Dir = worktreePath
	if err := cmd.Run(); err != nil {
		core.PrintColorf(core.ColorYellow, "Warning: failed to pull current branch: %v", err)
	}

	if pullOnly {
		core.PrintColor(core.ColorGreen, "Update completed (pull only)")
		return nil
	}

	// Rebase current branch on main
	core.PrintColorf(core.ColorYellow, "Rebasing '%s' on '%s'...", currentBranch, mainBranch)
	cmd = exec.Command("git", "rebase", mainBranch)
	cmd.Dir = worktreePath
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		if forceRebase {
			core.PrintColor(core.ColorRed, "Rebase failed, but continuing due to --rebase flag")
		} else {
			core.PrintColor(core.ColorRed, "Rebase failed. You may need to resolve conflicts manually.")
			core.PrintColor(core.ColorYellow, "Use 'git rebase --continue' after resolving conflicts or 'git rebase --abort' to cancel")
			return fmt.Errorf("rebase failed")
		}
	}

	// Install dependencies if needed
	if err := core.InstallDependencies(worktreePath); err != nil {
		core.PrintColorf(core.ColorYellow, "Warning: dependency installation failed: %v", err)
	}

	core.PrintColorf(core.ColorGreen, "Successfully updated worktree '%s'", worktreeName)
	return nil
}

func updateAllWorktrees(repoPath, mainBranch string, pullOnly, forceRebase bool) error {
	// Get list of worktrees
	cmd := exec.Command("git", "worktree", "list", "--porcelain")
	cmd.Dir = repoPath
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to list worktrees: %w", err)
	}

	var worktreePaths []string
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "worktree ") {
			path := strings.TrimPrefix(line, "worktree ")
			// Skip the main worktree (usually the repo root)
			if path != repoPath {
				worktreePaths = append(worktreePaths, path)
			}
		}
	}

	if len(worktreePaths) == 0 {
		core.PrintColor(core.ColorYellow, "No worktrees found to update")
		return nil
	}

	core.PrintColorf(core.ColorCyan, "Updating %d worktrees...", len(worktreePaths))

	// Update each worktree
	for _, worktreePath := range worktreePaths {
		worktreeName := filepath.Base(worktreePath)
		core.PrintColorf(core.ColorCyan, "\nUpdating worktree '%s'...", worktreeName)

		if err := updateWorktree(repoPath, worktreeName, mainBranch, pullOnly, forceRebase); err != nil {
			core.PrintColorf(core.ColorRed, "Failed to update worktree '%s': %v", worktreeName, err)
			continue
		}
	}

	core.PrintColor(core.ColorGreen, "\nAll worktrees updated")
	return nil
}
