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

var renameCmd = &cobra.Command{
	Use:   "rename [old-name] [new-name]",
	Short: "Rename a git worktree",
	Long:  `Rename a git worktree by moving the directory and updating git references`,
	Args:  cobra.RangeArgs(0, 2),
	RunE:  runRename,
}

func init() {
	renameCmd.Flags().BoolP("force", "f", false, "Force rename even if target exists")
}

func runRename(cmd *cobra.Command, args []string) error {
	cfg := config.NewConfig()
	force, _ := cmd.Flags().GetBool("force")

	// Select repository
	repoPath, err := core.SelectRepository(cfg.ProgrammingDir)
	if err != nil {
		return fmt.Errorf("failed to select repository: %w", err)
	}

	var oldName, newName string

	// Get old worktree name
	if len(args) >= 1 {
		oldName = args[0]
	} else {
		selected, err := selectWorktreeToRename(repoPath)
		if err != nil {
			return fmt.Errorf("failed to select worktree: %w", err)
		}
		oldName = selected
	}

	// Get new worktree name
	if len(args) >= 2 {
		newName = args[1]
	} else {
		input, err := core.PromptForInput(fmt.Sprintf("Enter new name for worktree '%s': ", oldName))
		if err != nil {
			return fmt.Errorf("failed to get new name: %w", err)
		}
		newName = strings.TrimSpace(input)
	}

	if newName == "" {
		return fmt.Errorf("new name cannot be empty")
	}

	if !core.IsValidBranchName(newName) {
		return fmt.Errorf("invalid name: %s", newName)
	}

	return renameWorktree(repoPath, oldName, newName, force)
}

func selectWorktreeToRename(repoPath string) (string, error) {
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
		return "", fmt.Errorf("no worktrees found to rename")
	}

	return core.PromptForChoice("Select worktree to rename:", worktrees)
}

func renameWorktree(repoPath, oldName, newName string, force bool) error {
	oldPath := filepath.Join(repoPath, oldName)
	newPath := filepath.Join(repoPath, newName)

	// Check if old worktree exists
	if _, err := os.Stat(oldPath); os.IsNotExist(err) {
		return fmt.Errorf("worktree '%s' does not exist", oldName)
	}

	// Check if new path already exists
	if _, err := os.Stat(newPath); err == nil {
		if !force {
			return fmt.Errorf("target '%s' already exists (use --force to override)", newName)
		}
		core.PrintColorf(core.ColorYellow, "Warning: target '%s' exists, removing it first", newName)
		if err := os.RemoveAll(newPath); err != nil {
			return fmt.Errorf("failed to remove existing target: %w", err)
		}
	}

	core.PrintColorf(core.ColorCyan, "Renaming worktree '%s' to '%s'...", oldName, newName)

	// Check if there are uncommitted changes
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = oldPath
	output, err := cmd.Output()
	if err == nil && len(strings.TrimSpace(string(output))) > 0 {
		core.PrintColorf(core.ColorYellow, "Warning: worktree '%s' has uncommitted changes", oldName)
		if !force {
			response, err := core.PromptForInput("Continue with rename? [y/N]: ")
			if err != nil {
				return fmt.Errorf("failed to get confirmation: %w", err)
			}
			if strings.ToLower(strings.TrimSpace(response)) != "y" {
				return fmt.Errorf("rename cancelled")
			}
		}
	}

	// Get the current branch name in the worktree
	cmd = exec.Command("git", "branch", "--show-current")
	cmd.Dir = oldPath
	output, err = cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get current branch: %w", err)
	}
	currentBranch := strings.TrimSpace(string(output))

	// Method 1: Try using git worktree move (available in newer Git versions)
	cmd = exec.Command("git", "worktree", "move", oldPath, newPath)
	cmd.Dir = repoPath
	if err := cmd.Run(); err != nil {
		// Method 2: Fallback to manual approach
		core.PrintColor(core.ColorYellow, "Git worktree move not available, using manual approach...")

		// Step 1: Remove the worktree from git
		cmd = exec.Command("git", "worktree", "remove", oldPath)
		cmd.Dir = repoPath
		if err := cmd.Run(); err != nil {
			// If remove fails, try force remove
			cmd = exec.Command("git", "worktree", "remove", "--force", oldPath)
			cmd.Dir = repoPath
			if err := cmd.Run(); err != nil {
				return fmt.Errorf("failed to remove worktree from git: %w", err)
			}
		}

		// Step 2: Move the directory
		if err := os.Rename(oldPath, newPath); err != nil {
			// If rename fails, try to recreate the worktree
			cmd := exec.Command("git", "worktree", "add", oldPath, currentBranch)
			cmd.Dir = repoPath
			cmd.Run() // Best effort to restore
			return fmt.Errorf("failed to move directory: %w", err)
		}

		// Step 3: Re-add the worktree to git
		cmd = exec.Command("git", "worktree", "add", newPath, currentBranch)
		cmd.Dir = repoPath
		if err := cmd.Run(); err != nil {
			// If re-adding fails, try to move directory back and restore worktree
			os.Rename(newPath, oldPath)
			cmd := exec.Command("git", "worktree", "add", oldPath, currentBranch)
			cmd.Dir = repoPath
			cmd.Run()
			return fmt.Errorf("failed to re-add worktree to git: %w", err)
		}
	}

	// Verify the rename was successful
	if _, err := os.Stat(newPath); err != nil {
		return fmt.Errorf("rename verification failed: new path does not exist")
	}

	// Check git status
	cmd = exec.Command("git", "status")
	cmd.Dir = newPath
	if err := cmd.Run(); err != nil {
		core.PrintColorf(core.ColorYellow, "Warning: git status check failed in renamed worktree: %v", err)
	}

	// Install dependencies if needed
	if err := core.InstallDependencies(newPath); err != nil {
		core.PrintColorf(core.ColorYellow, "Warning: dependency installation failed: %v", err)
	}

	core.PrintColorf(core.ColorGreen, "Successfully renamed worktree '%s' to '%s'", oldName, newName)
	core.PrintColorf(core.ColorCyan, "Worktree location: %s", newPath)

	return nil
}
