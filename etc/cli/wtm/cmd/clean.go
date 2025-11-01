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

var cleanCmd = &cobra.Command{
	Use:   "clean",
	Short: "Clean up stale worktree references and orphaned directories",
	Long:  `Clean up stale worktree references and remove orphaned worktree directories that no longer exist in git`,
	RunE:  runClean,
}

func init() {
	cleanCmd.Flags().BoolP("dry-run", "n", false, "Show what would be cleaned without actually doing it")
	cleanCmd.Flags().BoolP("force", "f", false, "Force cleanup without confirmation")
}

func runClean(cmd *cobra.Command, args []string) error {
	cfg := config.NewConfig()
	dryRun, _ := cmd.Flags().GetBool("dry-run")
	force, _ := cmd.Flags().GetBool("force")

	// Select repository
	repoPath, err := core.SelectRepository(cfg.ProgrammingDir)
	if err != nil {
		return fmt.Errorf("failed to select repository: %w", err)
	}

	return cleanWorktrees(repoPath, dryRun, force)
}

func cleanWorktrees(repoPath string, dryRun, force bool) error {
	core.PrintColor(core.ColorCyan, "Scanning for cleanup opportunities...")

	// Get current git worktree list
	gitWorktrees, err := getGitWorktreeList(repoPath)
	if err != nil {
		return fmt.Errorf("failed to get git worktree list: %w", err)
	}

	// Get physical directories in repo
	physicalDirs, err := getPhysicalWorktreeDirs(repoPath)
	if err != nil {
		return fmt.Errorf("failed to get physical directories: %w", err)
	}

	// Find orphaned directories (exist physically but not in git)
	orphanedDirs := findOrphanedDirectories(gitWorktrees, physicalDirs, repoPath)

	// Find stale git references (exist in git but not physically)
	staleRefs := findStaleReferences(gitWorktrees, physicalDirs)

	if len(orphanedDirs) == 0 && len(staleRefs) == 0 {
		core.PrintColor(core.ColorGreen, "No cleanup needed. Repository is clean!")
		return nil
	}

	// Display what will be cleaned
	if len(orphanedDirs) > 0 {
		core.PrintColor(core.ColorYellow, "\nOrphaned directories (exist physically but not in git):")
		for _, dir := range orphanedDirs {
			core.PrintColorf(core.ColorRed, "  - %s", dir)
		}
	}

	if len(staleRefs) > 0 {
		core.PrintColor(core.ColorYellow, "\nStale git references (exist in git but not physically):")
		for _, ref := range staleRefs {
			core.PrintColorf(core.ColorRed, "  - %s", ref)
		}
	}

	if dryRun {
		core.PrintColor(core.ColorCyan, "\nDry run mode - no changes will be made")
		return nil
	}

	// Confirm cleanup unless force is used
	if !force {
		totalItems := len(orphanedDirs) + len(staleRefs)
		fmt.Printf("\nProceed with cleanup of %d items? [y/N]: ", totalItems)
		reader := bufio.NewReader(os.Stdin)
		response, err := reader.ReadString('\n')
		if err != nil {
			return fmt.Errorf("failed to read confirmation: %w", err)
		}

		response = strings.TrimSpace(strings.ToLower(response))
		if response != "y" && response != "yes" {
			core.PrintColor(core.ColorYellow, "Cleanup cancelled")
			return nil
		}
	}

	// Perform cleanup
	var errors []string

	// Clean orphaned directories
	for _, dir := range orphanedDirs {
		core.PrintColorf(core.ColorYellow, "Removing orphaned directory: %s", filepath.Base(dir))
		if err := os.RemoveAll(dir); err != nil {
			errorMsg := fmt.Sprintf("failed to remove %s: %v", dir, err)
			errors = append(errors, errorMsg)
			core.PrintColorf(core.ColorRed, "Error: %s", errorMsg)
		} else {
			core.PrintColorf(core.ColorGreen, "Removed: %s", filepath.Base(dir))
		}
	}

	// Clean stale git references
	for _, ref := range staleRefs {
		core.PrintColorf(core.ColorYellow, "Removing stale git reference: %s", ref)
		cmd := exec.Command("git", "worktree", "prune")
		cmd.Dir = repoPath
		if err := cmd.Run(); err != nil {
			errorMsg := fmt.Sprintf("failed to prune git worktrees: %v", err)
			errors = append(errors, errorMsg)
			core.PrintColorf(core.ColorRed, "Error: %s", errorMsg)
		} else {
			core.PrintColorf(core.ColorGreen, "Pruned stale references")
		}
		break // git worktree prune handles all stale refs at once
	}

	// Summary
	if len(errors) > 0 {
		core.PrintColorf(core.ColorRed, "\nCleanup completed with %d errors:", len(errors))
		for _, err := range errors {
			core.PrintColorf(core.ColorRed, "  - %s", err)
		}
		return fmt.Errorf("cleanup completed with errors")
	}

	core.PrintColor(core.ColorGreen, "\nCleanup completed successfully!")
	return nil
}

func getGitWorktreeList(repoPath string) (map[string]bool, error) {
	cmd := exec.Command("git", "worktree", "list", "--porcelain")
	cmd.Dir = repoPath
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	worktrees := make(map[string]bool)
	lines := strings.Split(string(output), "\n")

	for _, line := range lines {
		if strings.HasPrefix(line, "worktree ") {
			path := strings.TrimPrefix(line, "worktree ")
			worktrees[path] = true
		}
	}

	return worktrees, nil
}

func getPhysicalWorktreeDirs(repoPath string) ([]string, error) {
	var dirs []string

	entries, err := os.ReadDir(repoPath)
	if err != nil {
		return nil, err
	}

	for _, entry := range entries {
		if entry.IsDir() {
			fullPath := filepath.Join(repoPath, entry.Name())

			// Skip special directories
			if entry.Name() == ".git" ||
				entry.Name() == "node_modules" ||
				entry.Name() == ".vscode" ||
				entry.Name() == ".idea" ||
				strings.HasPrefix(entry.Name(), ".") {
				continue
			}

			// Check if it looks like a worktree (has .git file or directory)
			gitPath := filepath.Join(fullPath, ".git")
			if _, err := os.Stat(gitPath); err == nil {
				dirs = append(dirs, fullPath)
			}
		}
	}

	return dirs, nil
}

func findOrphanedDirectories(gitWorktrees map[string]bool, physicalDirs []string, repoPath string) []string {
	var orphaned []string

	for _, dir := range physicalDirs {
		if !gitWorktrees[dir] {
			// Additional check: make sure it's not the main repository
			if dir != repoPath {
				orphaned = append(orphaned, dir)
			}
		}
	}

	return orphaned
}

func findStaleReferences(gitWorktrees map[string]bool, physicalDirs []string) []string {
	var stale []string

	// Create a map of physical directories for quick lookup
	physicalMap := make(map[string]bool)
	for _, dir := range physicalDirs {
		physicalMap[dir] = true
	}

	for path := range gitWorktrees {
		if !physicalMap[path] {
			// Check if the path exists at all
			if _, err := os.Stat(path); os.IsNotExist(err) {
				stale = append(stale, path)
			}
		}
	}

	return stale
}
