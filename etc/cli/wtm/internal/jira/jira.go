package jira

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
	"wtm/internal/core"
)

// JiraIssue represents a JIRA issue response
type JiraIssue struct {
	Fields struct {
		Summary string `json:"summary"`
	} `json:"fields"`
}

// GetJiraSummary fetches JIRA ticket summary using the JIRA CLI
func GetJiraSummary(jiraKey string) (string, error) {
	if jiraKey == "" {
		return "", fmt.Errorf("JIRA key is required")
	}

	if !core.CheckTool("jira") {
		return "", fmt.Errorf("JIRA CLI not found. Please install it first")
	}

	if !core.CheckTool("jq") {
		return "", fmt.Errorf("jq not found. Please install it first")
	}

	core.PrintColorf(core.ColorBlue, "Fetching JIRA ticket: %s", jiraKey)

	cmd := exec.Command("jira", "issue", "view", jiraKey, "--raw")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to fetch JIRA ticket %s: %w", jiraKey, err)
	}

	if len(output) == 0 {
		return "", fmt.Errorf("empty response from JIRA CLI for ticket: %s", jiraKey)
	}

	var issue JiraIssue
	if err := json.Unmarshal(output, &issue); err != nil {
		return "", fmt.Errorf("failed to parse JIRA response: %w", err)
	}

	if issue.Fields.Summary == "" {
		return "", fmt.Errorf("could not extract summary from JIRA ticket: %s", jiraKey)
	}

	core.PrintColorf(core.ColorBlue, "Successfully extracted summary: %s", issue.Fields.Summary)
	return issue.Fields.Summary, nil
}

// FormatBranchName formats a branch name from prefix, JIRA key, and summary
func FormatBranchName(prefix, jiraKey, summary string) (string, error) {
	if prefix == "" {
		return "", fmt.Errorf("prefix is required for branch name formatting")
	}

	if jiraKey == "" {
		return "", fmt.Errorf("JIRA key is required for branch name formatting")
	}

	if summary == "" {
		return "", fmt.Errorf("summary is required for branch name formatting")
	}

	jiraKeyLow := strings.ToLower(jiraKey)
	slug := Slugify(summary)

	if slug == "" {
		return "", fmt.Errorf("slugified summary is empty")
	}

	branchName := fmt.Sprintf("%s/%s_%s", prefix, jiraKeyLow, slug)
	core.PrintColorf(core.ColorBlue, "Generated branch name: %s", branchName)
	return branchName, nil
}

// FormatCommitTitle formats a commit title from prefix, emoji, JIRA key, and summary
func FormatCommitTitle(prefix, emoji, jiraKey, summary string) (string, error) {
	if prefix == "" {
		return "", fmt.Errorf("prefix is required for commit title formatting")
	}

	if emoji == "" {
		return "", fmt.Errorf("emoji is required for commit title formatting")
	}

	if jiraKey == "" {
		return "", fmt.Errorf("JIRA key is required for commit title formatting")
	}

	if summary == "" {
		return "", fmt.Errorf("summary is required for commit title formatting")
	}

	jiraKeyUp := strings.ToUpper(jiraKey)
	summaryCommit := strings.ToLower(summary)
	// Remove non-alphanumeric characters and normalize spaces
	re := regexp.MustCompile(`[^a-z0-9 ]`)
	summaryCommit = re.ReplaceAllString(summaryCommit, "")
	re = regexp.MustCompile(`\s+`)
	summaryCommit = re.ReplaceAllString(summaryCommit, " ")
	summaryCommit = strings.TrimSpace(summaryCommit)

	commitTitle := fmt.Sprintf("%s: %s %s %s", prefix, emoji, jiraKeyUp, summaryCommit)
	core.PrintColorf(core.ColorBlue, "Generated commit title: %s", commitTitle)
	return commitTitle, nil
}

// ValidateJiraKey validates JIRA key format
func ValidateJiraKey(jiraKey, pattern string) bool {
	if pattern == "" {
		pattern = `^[A-Z]+-[0-9]+$`
	}

	re := regexp.MustCompile(pattern)
	if !re.MatchString(jiraKey) {
		core.PrintColorf(core.ColorYellow, "Warning: JIRA key '%s' doesn't match expected format (e.g., SB-1234)", jiraKey)

		// Prompt user to continue
		input, err := core.PromptForInput("Continue anyway? (y/n): ")
		if err != nil || !strings.HasPrefix(strings.ToLower(input), "y") {
			return false
		}
	}
	return true
}

// ProcessJiraTicket processes a JIRA ticket for worktree creation
func ProcessJiraTicket(prefix, emoji string) (*JiraResult, error) {
	jiraKey, err := core.PromptForInput("Enter Jira ticket number (e.g. SB-1234): ")
	if err != nil {
		return nil, err
	}

	if jiraKey == "" {
		return nil, fmt.Errorf("no Jira key entered")
	}

	// Validate JIRA key format
	if !ValidateJiraKey(jiraKey, "") {
		return nil, fmt.Errorf("operation cancelled")
	}

	core.PrintColorf(core.ColorYellow, "Fetching Jira ticket details for %s...", jiraKey)

	summary, err := GetJiraSummary(jiraKey)
	if err != nil {
		core.PrintColor(core.ColorRed, "Failed to get JIRA summary. You can:")
		core.PrintColor(core.ColorYellow, "  1. Continue with manual entry (recommended)")
		core.PrintColor(core.ColorYellow, "  2. Exit and fix JIRA configuration")

		input, promptErr := core.PromptForInput("Continue with manual entry? (y/n): ")
		if promptErr != nil || !strings.HasPrefix(strings.ToLower(input), "y") {
			return nil, fmt.Errorf("operation cancelled")
		}
		return nil, fmt.Errorf("fallback to manual entry")
	}

	if summary == "" {
		return nil, fmt.Errorf("empty summary returned from JIRA")
	}

	core.PrintColorf(core.ColorGreen, "Found: %s", summary)

	branchName, err := FormatBranchName(prefix, jiraKey, summary)
	if err != nil {
		return nil, fmt.Errorf("failed to format branch name: %w", err)
	}

	commitTitle, err := FormatCommitTitle(prefix, emoji, jiraKey, summary)
	if err != nil {
		return nil, fmt.Errorf("failed to format commit title: %w", err)
	}

	jiraKeyUp := strings.ToUpper(jiraKey)
	slug := Slugify(summary)
	folderName := fmt.Sprintf("%s_%s", jiraKeyUp, slug)
	core.PrintColorf(core.ColorBlue, "Folder name: %s", folderName)

	return &JiraResult{
		BranchName:  branchName,
		CommitTitle: commitTitle,
		FolderName:  folderName,
		JiraKey:     jiraKey,
		Summary:     summary,
	}, nil
}

// JiraResult holds the results of JIRA processing
type JiraResult struct {
	BranchName  string
	CommitTitle string
	FolderName  string
	JiraKey     string
	Summary     string
}

// Slugify converts a string to a URL-friendly slug
func Slugify(s string) string {
	// Convert to lowercase
	s = strings.ToLower(s)

	// Replace non-alphanumeric characters with dashes
	re := regexp.MustCompile(`[^a-z0-9]+`)
	s = re.ReplaceAllString(s, "-")

	// Remove leading and trailing dashes
	s = strings.Trim(s, "-")

	// Replace multiple consecutive dashes with single dash
	re = regexp.MustCompile(`-+`)
	s = re.ReplaceAllString(s, "-")

	return s
}

// CleanJiraSummary cleans a JIRA summary for use in branch names
func CleanJiraSummary(summary string) string {
	return Slugify(summary)
}

// CreateBranchFromJira creates a branch name from a JIRA ticket
func CreateBranchFromJira(jiraTicket string) string {
	if jiraTicket == "" {
		return ""
	}

	summary, err := GetJiraSummary(jiraTicket)
	if err == nil && summary != "" {
		cleanSummary := CleanJiraSummary(summary)
		return fmt.Sprintf("%s-%s", jiraTicket, cleanSummary)
	}

	// Fallback to just the ticket number
	return jiraTicket
}
