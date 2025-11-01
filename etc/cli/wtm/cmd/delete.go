package cmd

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"wtm/internal/config"
	"wtm/internal/core"
)

var deleteCmd = &cobra.Command{
	Use:   "delete [worktree]",
	Short: "Delete a git worktree",
	Long:  `Delete a git worktree and remove its directory`,
	Args:  cobra.MaximumNArgs(1),
	RunE:  runDelete,
}

func init() {
	deleteCmd.Flags().BoolP("force", "f", false, "Force delete without confirmation")
	deleteCmd.Flags().BoolP("all", "a", false, "Delete all worktrees except main")
}

func runDelete(cmd *cobra.Command, args []string) error {
	cfg := config.NewConfig()
	force, _ := cmd.Flags().GetBool("force")
	all, _ := cmd.Flags().GetBool("all")

	// Select repository
	repoPath, err := core.SelectRepository(cfg.ProgrammingDir)
	if err != nil {
		return fmt.Errorf("failed to select repository: %w", err)
	}

	if all {
		return deleteAllWorktrees(repoPath, force)
	}

	var worktreeName string
	if len(args) > 0 {
		worktreeName = args[0]
	} else {
		// Get list of worktrees and let user select
		selected, err := selectWorktreeToDelete(repoPath)
		if err != nil {
			return fmt.Errorf("failed to select worktree: %w", err)
		}
		worktreeName = selected
	}

	return deleteWorktree(repoPath, worktreeName, force)
}

func selectWorktreeToDelete(repoPath string) (string, error) {
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
		return "", fmt.Errorf("no worktrees found to delete")
	}

	return core.PromptForChoice("Select worktree to delete:", worktrees)
}

func deleteWorktree(repoPath, worktreeName string, force bool) error {
	worktreePath := filepath.Join(repoPath, worktreeName)

	// Check if worktree exists
	if _, err := os.Stat(worktreePath); os.IsNotExist(err) {
		return fmt.Errorf("worktree '%s' does not exist", worktreeName)
	}

	// Confirm deletion unless force is used
	if !force {
		fmt.Printf("Are you sure you want to delete worktree '%s'? [y/N]: ", worktreeName)
		reader := bufio.NewReader(os.Stdin)
		response, err := reader.ReadString('\n')
		if err != nil {
			return fmt.Errorf("failed to read confirmation: %w", err)
		}

		response = strings.TrimSpace(strings.ToLower(response))
		if response != "y" && response != "yes" {
			fmt.Println("Deletion cancelled")
			return nil
		}
	}

	// Check if there are uncommitted changes
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = worktreePath
	output, err := cmd.Output()
	if err == nil && len(strings.TrimSpace(string(output))) > 0 {
		if !force {
			fmt.Printf("Worktree '%s' has uncommitted changes. Continue? [y/N]: ", worktreeName)
			reader := bufio.NewReader(os.Stdin)
			response, err := reader.ReadString('\n')
			if err != nil {
				return fmt.Errorf("failed to read confirmation: %w", err)
			}

			response = strings.TrimSpace(strings.ToLower(response))
			if response != "y" && response != "yes" {
				fmt.Println("Deletion cancelled")
				return nil
			}
		}
	}

	// Remove the worktree
	cmd = exec.Command("git", "worktree", "remove", worktreePath)
	cmd.Dir = repoPath
	if err := cmd.Run(); err != nil {
		// If git worktree remove fails, try to force remove
		cmd = exec.Command("git", "worktree", "remove", "--force", worktreePath)
		cmd.Dir = repoPath
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to remove worktree: %w", err)
		}
	}

	fmt.Printf("Successfully deleted worktree '%s'\n", worktreeName)
	return nil
}

func deleteAllWorktrees(repoPath string, force bool) error {
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
		fmt.Println("No worktrees found to delete")
		return nil
	}

	// Confirm deletion unless force is used
	if !force {
		fmt.Printf("Are you sure you want to delete all %d worktrees? [y/N]: ", len(worktreePaths))
		reader := bufio.NewReader(os.Stdin)
		response, err := reader.ReadString('\n')
		if err != nil {
			return fmt.Errorf("failed to read confirmation: %w", err)
		}

		response = strings.TrimSpace(strings.ToLower(response))
		if response != "y" && response != "yes" {
			fmt.Println("Deletion cancelled")
			return nil
		}
	}

	// Delete each worktree
	for _, worktreePath := range worktreePaths {
		worktreeName := filepath.Base(worktreePath)
		fmt.Printf("Deleting worktree '%s'...\n", worktreeName)

		// Remove the worktree
		cmd := exec.Command("git", "worktree", "remove", worktreePath)
		cmd.Dir = repoPath
		if err := cmd.Run(); err != nil {
			// If git worktree remove fails, try to force remove
			cmd = exec.Command("git", "worktree", "remove", "--force", worktreePath)
			cmd.Dir = repoPath
			if err := cmd.Run(); err != nil {
				fmt.Printf("Failed to remove worktree '%s': %v\n", worktreeName, err)
				continue
			}
		}

		fmt.Printf("Successfully deleted worktree '%s'\n", worktreeName)
	}

	return nil
}
