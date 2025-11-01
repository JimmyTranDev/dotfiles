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

var checkoutCmd = &cobra.Command{
	Use:   "checkout [branch]",
	Short: "Checkout existing remote branch as worktree",
	Long: `Checkout an existing remote branch as a new worktree.

Examples:
  wtm checkout feature/new-feature    # Checkout specific branch
  wtm checkout                        # Interactive branch selection`,
	RunE: runCheckout,
}

func runCheckout(cmd *cobra.Command, args []string) error {
	cfg := config.NewConfig()

	if !core.CheckTool("git") {
		return fmt.Errorf("git is required but not found")
	}

	if !core.CheckTool("fzf") {
		core.PrintColor(core.ColorYellow, "fzf not found. Using basic selection interface.")
	}

	// Get repository
	repoDir, err := core.SelectRepository(cfg.ProgrammingDir)
	if err != nil {
		return fmt.Errorf("repository selection failed: %w", err)
	}

	// Fetch latest remote refs
	core.PrintColor(core.ColorYellow, "Fetching latest remote branches...")
	cmdFetch := exec.Command("git", "-C", repoDir, "fetch", "origin")
	if err := cmdFetch.Run(); err != nil {
		return fmt.Errorf("failed to fetch from origin: %w", err)
	}

	// Get all remote branches
	cmdBranches := exec.Command("git", "-C", repoDir, "branch", "-r")
	output, err := cmdBranches.Output()
	if err != nil {
		return fmt.Errorf("failed to get remote branches: %w", err)
	}

	var remoteBranches []string
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "origin/") && !strings.Contains(line, "HEAD") {
			branch := strings.TrimPrefix(line, "origin/")
			remoteBranches = append(remoteBranches, branch)
		}
	}

	if len(remoteBranches) == 0 {
		return fmt.Errorf("no remote branches found")
	}

	var branchSel string
	if len(args) > 0 {
		branchSel = args[0]
		// Verify the branch exists
		found := false
		for _, branch := range remoteBranches {
			if branch == branchSel {
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("branch '%s' not found in remote branches", branchSel)
		}
	} else {
		// Interactive selection
		if core.CheckTool("fzf") {
			selected, err := core.SelectWithFuzzyFinder("Select remote branch to checkout:", remoteBranches)
			if err != nil {
				return fmt.Errorf("branch selection failed: %w", err)
			}
			branchSel = selected
		} else {
			selected, err := core.PromptForChoice("Select remote branch to checkout:", remoteBranches)
			if err != nil {
				return fmt.Errorf("branch selection failed: %w", err)
			}
			branchSel = selected
		}
	}

	if branchSel == "" {
		return fmt.Errorf("no branch selected")
	}

	localBranch := branchSel

	// Ensure worktrees directory exists
	if err := os.MkdirAll(cfg.WorktreesDir, 0755); err != nil {
		return fmt.Errorf("could not create worktrees directory: %w", err)
	}

	folderName, err := core.GetFolderNameFromBranch(localBranch)
	if err != nil {
		return err
	}

	worktreePath := filepath.Join(cfg.WorktreesDir, folderName)

	// Check if worktree already exists
	if _, err := os.Stat(worktreePath); err == nil {
		core.PrintColorf(core.ColorYellow, "Worktree already exists at: %s", worktreePath)

		// Check if it's a valid git worktree
		cmdList := exec.Command("git", "-C", repoDir, "worktree", "list")
		listOutput, err := cmdList.Output()
		if err == nil && strings.Contains(string(listOutput), worktreePath) {
			core.PrintColorf(core.ColorGreen, "Switching to existing worktree: %s", worktreePath)
			if err := os.Chdir(worktreePath); err != nil {
				return fmt.Errorf("could not change to worktree directory: %w", err)
			}
			core.PrintColor(core.ColorGreen, "Successfully switched to worktree!")
			return nil
		} else {
			// Directory exists but not a valid worktree
			choice, err := core.PromptForChoice("Directory exists but is not a valid git worktree. What would you like to do?",
				[]string{"Remove directory and create new worktree", "Cancel operation"})
			if err != nil || choice != "Remove directory and create new worktree" {
				core.PrintColor(core.ColorYellow, "Operation cancelled")
				return nil
			}

			if err := os.RemoveAll(worktreePath); err != nil {
				return fmt.Errorf("failed to remove existing directory: %w", err)
			}
			core.PrintColor(core.ColorGreen, "Removed existing directory")
		}
	}

	// Check if local branch already exists
	cmdShowRef := exec.Command("git", "-C", repoDir, "show-ref", "--verify", "--quiet", "refs/heads/"+localBranch)
	if cmdShowRef.Run() == nil {
		core.PrintColorf(core.ColorYellow, "Local branch '%s' already exists. Creating worktree from existing branch.", localBranch)

		cmdWorktree := exec.Command("git", "-C", repoDir, "worktree", "add", worktreePath, localBranch)
		if err := cmdWorktree.Run(); err != nil {
			// Try to clean up and retry
			cmdRemove := exec.Command("git", "-C", repoDir, "worktree", "remove", worktreePath)
			cmdRemove.Run() // Ignore error

			cmdWorktree = exec.Command("git", "-C", repoDir, "worktree", "add", worktreePath, localBranch)
			if err := cmdWorktree.Run(); err != nil {
				return fmt.Errorf("failed to create worktree from existing branch: %w", err)
			}
		}
	} else {
		core.PrintColorf(core.ColorGreen, "Creating new branch '%s' with worktree.", localBranch)

		cmdWorktree := exec.Command("git", "-C", repoDir, "worktree", "add", worktreePath, "-b", localBranch, "origin/"+localBranch)
		if err := cmdWorktree.Run(); err != nil {
			// Try to clean up and retry
			cmdRemove := exec.Command("git", "-C", repoDir, "worktree", "remove", worktreePath)
			cmdRemove.Run() // Ignore error

			cmdWorktree = exec.Command("git", "-C", repoDir, "worktree", "add", worktreePath, "-b", localBranch, "origin/"+localBranch)
			if err := cmdWorktree.Run(); err != nil {
				return fmt.Errorf("failed to create worktree with new branch: %w", err)
			}
		}
	}

	core.PrintColorf(core.ColorGreen, "Worktree created at: %s", worktreePath)

	// Install dependencies and navigate to worktree
	if err := core.InstallDependencies(worktreePath); err != nil {
		core.PrintColor(core.ColorYellow, "Warning: Dependency installation failed")
	}

	// Navigate to the worktree directory
	if err := os.Chdir(worktreePath); err != nil {
		core.PrintColor(core.ColorYellow, "Warning: Could not navigate to worktree directory")
	}

	core.PrintColor(core.ColorGreen, "Checkout completed successfully!")
	return nil
}
