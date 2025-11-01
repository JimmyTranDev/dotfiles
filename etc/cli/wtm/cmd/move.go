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

var moveCmd = &cobra.Command{
	Use:   "move [worktree] [destination]",
	Short: "Move a git worktree to a different location",
	Long:  `Move a git worktree to a different directory location while maintaining git references`,
	Args:  cobra.RangeArgs(0, 2),
	RunE:  runMove,
}

func init() {
	moveCmd.Flags().BoolP("force", "f", false, "Force move even if destination exists")
}

func runMove(cmd *cobra.Command, args []string) error {
	cfg := config.NewConfig()
	force, _ := cmd.Flags().GetBool("force")

	// Select repository
	repoPath, err := core.SelectRepository(cfg.ProgrammingDir)
	if err != nil {
		return fmt.Errorf("failed to select repository: %w", err)
	}

	var worktreeName, destination string

	// Get worktree name
	if len(args) >= 1 {
		worktreeName = args[0]
	} else {
		selected, err := selectWorktreeToMove(repoPath)
		if err != nil {
			return fmt.Errorf("failed to select worktree: %w", err)
		}
		worktreeName = selected
	}

	// Get destination
	if len(args) >= 2 {
		destination = args[1]
	} else {
		input, err := core.PromptForInput(fmt.Sprintf("Enter destination path for worktree '%s': ", worktreeName))
		if err != nil {
			return fmt.Errorf("failed to get destination: %w", err)
		}
		destination = strings.TrimSpace(input)
	}

	if destination == "" {
		return fmt.Errorf("destination cannot be empty")
	}

	return moveWorktree(repoPath, worktreeName, destination, force)
}

func selectWorktreeToMove(repoPath string) (string, error) {
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
		return "", fmt.Errorf("no worktrees found to move")
	}

	return core.PromptForChoice("Select worktree to move:", worktrees)
}

func moveWorktree(repoPath, worktreeName, destination string, force bool) error {
	currentPath := filepath.Join(repoPath, worktreeName)

	// Check if current worktree exists
	if _, err := os.Stat(currentPath); os.IsNotExist(err) {
		return fmt.Errorf("worktree '%s' does not exist", worktreeName)
	}

	// Resolve destination path
	var newPath string
	if filepath.IsAbs(destination) {
		newPath = destination
	} else {
		// If relative path, make it relative to current working directory
		cwd, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("failed to get current directory: %w", err)
		}
		newPath = filepath.Join(cwd, destination)
	}

	// If destination is a directory, append the worktree name
	if info, err := os.Stat(newPath); err == nil && info.IsDir() {
		newPath = filepath.Join(newPath, worktreeName)
	}

	// Check if destination already exists
	if _, err := os.Stat(newPath); err == nil {
		if !force {
			return fmt.Errorf("destination '%s' already exists (use --force to override)", newPath)
		}
		core.PrintColorf(core.ColorYellow, "Warning: destination '%s' exists, removing it first", newPath)
		if err := os.RemoveAll(newPath); err != nil {
			return fmt.Errorf("failed to remove existing destination: %w", err)
		}
	}

	// Ensure destination directory exists
	destDir := filepath.Dir(newPath)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	core.PrintColorf(core.ColorCyan, "Moving worktree '%s' from '%s' to '%s'...", worktreeName, currentPath, newPath)

	// Check if there are uncommitted changes
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = currentPath
	output, err := cmd.Output()
	if err == nil && len(strings.TrimSpace(string(output))) > 0 {
		core.PrintColorf(core.ColorYellow, "Warning: worktree '%s' has uncommitted changes", worktreeName)
		if !force {
			response, err := core.PromptForInput("Continue with move? [y/N]: ")
			if err != nil {
				return fmt.Errorf("failed to get confirmation: %w", err)
			}
			if strings.ToLower(strings.TrimSpace(response)) != "y" {
				return fmt.Errorf("move cancelled")
			}
		}
	}

	// Get the current branch name in the worktree
	cmd = exec.Command("git", "branch", "--show-current")
	cmd.Dir = currentPath
	output, err = cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get current branch: %w", err)
	}
	currentBranch := strings.TrimSpace(string(output))

	// Method 1: Try using git worktree move (available in newer Git versions)
	cmd = exec.Command("git", "worktree", "move", currentPath, newPath)
	cmd.Dir = repoPath
	if err := cmd.Run(); err != nil {
		// Method 2: Fallback to manual approach
		core.PrintColor(core.ColorYellow, "Git worktree move not available, using manual approach...")

		// Step 1: Remove the worktree from git
		cmd = exec.Command("git", "worktree", "remove", currentPath)
		cmd.Dir = repoPath
		if err := cmd.Run(); err != nil {
			// If remove fails, try force remove
			cmd = exec.Command("git", "worktree", "remove", "--force", currentPath)
			cmd.Dir = repoPath
			if err := cmd.Run(); err != nil {
				return fmt.Errorf("failed to remove worktree from git: %w", err)
			}
		}

		// Step 2: Move the directory
		if err := moveDirectory(currentPath, newPath); err != nil {
			// If move fails, try to recreate the worktree
			cmd := exec.Command("git", "worktree", "add", currentPath, currentBranch)
			cmd.Dir = repoPath
			cmd.Run() // Best effort to restore
			return fmt.Errorf("failed to move directory: %w", err)
		}

		// Step 3: Re-add the worktree to git
		cmd = exec.Command("git", "worktree", "add", newPath, currentBranch)
		cmd.Dir = repoPath
		if err := cmd.Run(); err != nil {
			// If re-adding fails, try to move directory back and restore worktree
			moveDirectory(newPath, currentPath)
			cmd := exec.Command("git", "worktree", "add", currentPath, currentBranch)
			cmd.Dir = repoPath
			cmd.Run()
			return fmt.Errorf("failed to re-add worktree to git: %w", err)
		}
	}

	// Verify the move was successful
	if _, err := os.Stat(newPath); err != nil {
		return fmt.Errorf("move verification failed: new path does not exist")
	}

	// Check git status
	cmd = exec.Command("git", "status")
	cmd.Dir = newPath
	if err := cmd.Run(); err != nil {
		core.PrintColorf(core.ColorYellow, "Warning: git status check failed in moved worktree: %v", err)
	}

	// Install dependencies if needed
	if err := core.InstallDependencies(newPath); err != nil {
		core.PrintColorf(core.ColorYellow, "Warning: dependency installation failed: %v", err)
	}

	core.PrintColorf(core.ColorGreen, "Successfully moved worktree '%s'", worktreeName)
	core.PrintColorf(core.ColorCyan, "New location: %s", newPath)

	return nil
}

func moveDirectory(src, dst string) error {
	// First try simple rename/move
	if err := os.Rename(src, dst); err == nil {
		return nil
	}

	// If that fails, try copy and remove (for cross-filesystem moves)
	if err := copyDirectory(src, dst); err != nil {
		return fmt.Errorf("failed to copy directory: %w", err)
	}

	// Remove source after successful copy
	if err := os.RemoveAll(src); err != nil {
		// Log warning but don't fail since copy succeeded
		core.PrintColorf(core.ColorYellow, "Warning: failed to remove source directory: %v", err)
	}

	return nil
}

func copyDirectory(src, dst string) error {
	// Get source directory info
	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}

	// Create destination directory
	if err := os.MkdirAll(dst, srcInfo.Mode()); err != nil {
		return err
	}

	// Read source directory
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	// Copy each entry
	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())

		if entry.IsDir() {
			if err := copyDirectory(srcPath, dstPath); err != nil {
				return err
			}
		} else {
			if err := copyFile(srcPath, dstPath); err != nil {
				return err
			}
		}
	}

	return nil
}

func copyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	srcInfo, err := srcFile.Stat()
	if err != nil {
		return err
	}

	dstFile, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, srcInfo.Mode())
	if err != nil {
		return err
	}
	defer dstFile.Close()

	// Copy file contents
	buf := make([]byte, 32*1024) // 32KB buffer
	for {
		n, err := srcFile.Read(buf)
		if n > 0 {
			if _, writeErr := dstFile.Write(buf[:n]); writeErr != nil {
				return writeErr
			}
		}
		if err != nil {
			if err.Error() == "EOF" {
				break
			}
			return err
		}
	}

	return nil
}
