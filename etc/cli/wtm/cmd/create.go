package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/spf13/cobra"
	"wtm/internal/config"
	"wtm/internal/core"
	"wtm/internal/jira"
)

var createCmd = &cobra.Command{
	Use:   "create [jira-ticket] [repo]",
	Short: "Create a new worktree",
	Long: `Create a new worktree for development.

Examples:
  wtm create ABC-123 my-repo    # Create worktree for JIRA ticket in specific repo
  wtm create ABC-123           # Create worktree for JIRA ticket (interactive repo selection)
  wtm create                   # Interactive creation (prompts for JIRA ticket and repository)`,
	RunE: runCreate,
}

func runCreate(cmd *cobra.Command, args []string) error {
	cfg := config.NewConfig()

	if !core.CheckTool("git") {
		return fmt.Errorf("git is required but not found")
	}

	if !core.CheckTool("fzf") {
		core.PrintColor(core.ColorYellow, "fzf not found. Using basic selection interface.")
	}

	var jiraTicket, repoName string
	if len(args) > 0 {
		jiraTicket = args[0]
	}
	if len(args) > 1 {
		repoName = args[1]
	}

	// Get repository first - either by name or interactive selection
	var mainRepo string
	if repoName != "" {
		core.PrintColorf(core.ColorYellow, "Looking for repository: %s", repoName)
		repo, err := core.FindRepositoryByName(repoName, cfg.ProgrammingDir)
		if err != nil {
			return fmt.Errorf("could not find repository '%s': %w", repoName, err)
		}
		mainRepo = repo
	} else {
		repo, err := core.SelectRepository(cfg.ProgrammingDir)
		if err != nil {
			return fmt.Errorf("repository selection failed: %w", err)
		}
		mainRepo = repo
	}

	core.PrintColorf(core.ColorYellow, "Using repository: %s", filepath.Base(mainRepo))
	core.PrintColorf(core.ColorYellow, "Repository path: %s", mainRepo)

	// Get the main branch for the selected repository
	mainBranch, err := core.FindMainBranch(mainRepo)
	if err != nil {
		return fmt.Errorf("could not find main branch in %s: %w", mainRepo, err)
	}

	core.PrintColorf(core.ColorYellow, "Base branch: %s", mainBranch)

	// Now prompt for JIRA ticket if not provided
	if jiraTicket == "" {
		input, err := core.PromptForInput("Enter JIRA ticket (e.g., ABC-123) or leave empty to skip JIRA integration: ")
		if err != nil {
			return err
		}
		jiraTicket = input
	}

	var branchName, summary string

	// Try to get JIRA summary if ticket provided
	if jiraTicket != "" && regexp.MustCompile(cfg.JiraPattern).MatchString(jiraTicket) {
		if !core.CheckTool("jira") {
			core.PrintColor(core.ColorYellow, "JIRA CLI not available. Proceeding without JIRA integration.")
			branchName = jiraTicket
		} else {
			core.PrintColor(core.ColorYellow, "Fetching JIRA ticket details...")

			ticketSummary, err := jira.GetJiraSummary(jiraTicket)
			if err == nil && ticketSummary != "" {
				core.PrintColorf(core.ColorGreen, "✅ JIRA ticket found: %s", ticketSummary)
				summary = ticketSummary
				cleanSummary := jira.CleanJiraSummary(summary)
				branchName = fmt.Sprintf("%s-%s", jiraTicket, cleanSummary)
			} else {
				core.PrintColor(core.ColorYellow, "Could not fetch JIRA summary. Using ticket number as branch name.")
				branchName = jiraTicket
			}
		}
	} else if jiraTicket != "" {
		// User provided something that's not a JIRA ticket
		branchName = jiraTicket
		core.PrintColor(core.ColorYellow, "Input doesn't match JIRA pattern. Using as branch name directly.")
	} else {
		// No input provided
		input, err := core.PromptForInput("Enter branch name: ")
		if err != nil {
			return err
		}
		branchName = input

		if branchName == "" {
			return fmt.Errorf("no branch name provided")
		}
	}

	// Sanitize branch name
	originalInput := branchName
	branchName = sanitizeBranchName(branchName)

	if branchName == "" {
		return fmt.Errorf("invalid branch name")
	}

	core.PrintColorf(core.ColorCyan, "Creating worktree for branch: %s", branchName)

	// Prompt for commit type selection
	core.PrintColor(core.ColorCyan, "Select commit type:")
	commitTypes := []string{"feat", "fix", "docs", "style", "refactor", "test", "chore", "revert", "build", "ci", "perf"}

	var commitType string
	if core.CheckTool("fzf") {
		selected, err := core.SelectWithFuzzyFinder("Select commit type:", commitTypes)
		if err != nil {
			// Fallback to manual selection
			selected, err = core.PromptForChoice("Select commit type:", commitTypes)
			if err != nil {
				commitType = "feat" // Default
			} else {
				commitType = selected
			}
		} else {
			commitType = selected
		}
	} else {
		selected, err := core.PromptForChoice("Select commit type:", commitTypes)
		if err != nil {
			commitType = "feat" // Default
		} else {
			commitType = selected
		}
	}

	if commitType == "" {
		commitType = "feat"
	}

	core.PrintColorf(core.ColorGreen, "Selected commit type: %s", commitType)

	// Create worktree directory path
	worktreeDir := filepath.Join(cfg.WorktreesDir, branchName)

	// Check if worktree directory already exists
	if _, err := os.Stat(worktreeDir); err == nil {
		return fmt.Errorf("worktree directory already exists: %s", worktreeDir)
	}

	// Ensure worktrees directory exists
	if err := os.MkdirAll(cfg.WorktreesDir, 0755); err != nil {
		return fmt.Errorf("could not create worktrees directory %s: %w", cfg.WorktreesDir, err)
	}

	core.PrintColorf(core.ColorYellow, "Creating worktree at: %s", worktreeDir)

	// Create and switch to the new worktree
	cmd_git := exec.Command("git", "-C", mainRepo, "worktree", "add", "-b", branchName, worktreeDir, mainBranch)
	if err := cmd_git.Run(); err != nil {
		return fmt.Errorf("failed to create worktree: %w", err)
	}

	core.PrintColor(core.ColorGreen, "✅ Worktree created successfully!")
	core.PrintColorf(core.ColorCyan, "📁 Path: %s", worktreeDir)
	core.PrintColorf(core.ColorCyan, "🌿 Branch: %s", branchName)

	// Create an empty initial commit
	core.PrintColor(core.ColorYellow, "Creating initial commit...")

	emoji := cfg.GetEmojiForType(commitType)
	var commitMessage string

	// Format commit message based on whether we have JIRA info
	if jiraTicket != "" && regexp.MustCompile(cfg.JiraPattern).MatchString(jiraTicket) {
		if summary != "" {
			commitMessage = fmt.Sprintf("%s: %s %s %s", commitType, emoji, jiraTicket, summary)
		} else {
			commitMessage = fmt.Sprintf("%s: %s %s", commitType, emoji, jiraTicket)
		}

		// Add JIRA link in the commit body if available
		if cfg.JiraTicketLink != "" {
			commitMessage = fmt.Sprintf("%s\n\nJira: %s%s", commitMessage, cfg.JiraTicketLink, jiraTicket)
		}
	} else {
		commitMessage = fmt.Sprintf("%s: %s %s", commitType, emoji, originalInput)
	}

	cmdCommit := exec.Command("git", "-C", worktreeDir, "commit", "--allow-empty", "-m", commitMessage)
	if err := cmdCommit.Run(); err != nil {
		core.PrintColor(core.ColorYellow, "Warning: Could not create initial commit")
	}

	if summary != "" {
		core.PrintColorf(core.ColorCyan, "📋 JIRA: %s - %s", jiraTicket, summary)
	}

	// Install dependencies if package.json exists
	if _, err := os.Stat(filepath.Join(worktreeDir, "package.json")); err == nil {
		core.PrintColor(core.ColorYellow, "📦 Package.json found. Installing dependencies...")

		if err := core.InstallDependencies(worktreeDir); err != nil {
			core.PrintColor(core.ColorYellow, "Warning: Dependency installation failed")
		}
	} else {
		core.PrintColor(core.ColorCyan, "No package.json found, skipping dependency installation")
	}

	// Change to worktree directory
	if err := os.Chdir(worktreeDir); err != nil {
		core.PrintColor(core.ColorYellow, "Warning: Could not navigate to worktree directory")
	}

	core.PrintColor(core.ColorYellow, "Now in worktree directory. Happy coding! 🚀")
	return nil
}

func sanitizeBranchName(branchName string) string {
	// Remove any ANSI color codes and normalize
	re := regexp.MustCompile(`\x1b\[[0-9;]*m`)
	branchName = re.ReplaceAllString(branchName, "")
	branchName = strings.TrimSpace(branchName)

	// Replace invalid characters with dashes
	re = regexp.MustCompile(`[^a-zA-Z0-9._-]`)
	branchName = re.ReplaceAllString(branchName, "-")

	// Replace multiple consecutive dashes with single dash
	re = regexp.MustCompile(`-+`)
	branchName = re.ReplaceAllString(branchName, "-")

	// Remove leading and trailing dashes
	branchName = strings.Trim(branchName, "-")

	return branchName
}
