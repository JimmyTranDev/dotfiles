package jira

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/fatih/color"
	"github.com/jimmy/worktree-cli/internal/ui"
)

// JIRAIssue represents a JIRA issue response
type JIRAIssue struct {
	Fields struct {
		Summary string `json:"summary"`
	} `json:"fields"`
}

// JIRAService handles JIRA operations
type JIRAService struct {
	pattern    *regexp.Regexp
	ticketLink string
}

// NewJIRAService creates a new JIRA service with the given configuration
func NewJIRAService(pattern, ticketLink string) (*JIRAService, error) {
	compiledPattern, err := regexp.Compile(pattern)
	if err != nil {
		return nil, fmt.Errorf("failed to compile JIRA pattern: %w", err)
	}

	return &JIRAService{
		pattern:    compiledPattern,
		ticketLink: ticketLink,
	}, nil
}

// ValidateTicket validates a JIRA ticket format
func (j *JIRAService) ValidateTicket(ticket string) bool {
	return j.pattern.MatchString(ticket)
}

// GetSummary fetches the JIRA ticket summary using the acli CLI
func (j *JIRAService) GetSummary(ctx context.Context, ticket string) (string, error) {
	if !j.ValidateTicket(ticket) {
		return "", fmt.Errorf("invalid JIRA ticket format: %s", ticket)
	}

	// Check if acli is available
	if _, err := exec.LookPath("acli"); err != nil {
		return "", fmt.Errorf("acli not found. Please install it first: %w", err)
	}

	// Create a timeout context for JIRA call (max 30 seconds)
	jiraCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	// Execute acli command to get only the summary field
	cmd := exec.CommandContext(jiraCtx, "acli", "jira", "workitem", "view", ticket, "--json", "--fields", "summary")
	output, err := cmd.Output()
	if err != nil {
		if jiraCtx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("JIRA API call timed out for ticket %s", ticket)
		}
		return "", fmt.Errorf("failed to fetch JIRA ticket %s: %w", ticket, err)
	}

	if len(output) == 0 {
		return "", fmt.Errorf("empty response from acli for ticket: %s", ticket)
	}

	// Parse JSON response
	var issue JIRAIssue
	if err := json.Unmarshal(output, &issue); err != nil {
		return "", fmt.Errorf("failed to parse JIRA response for %s: %w", ticket, err)
	}

	if issue.Fields.Summary == "" {
		return "", fmt.Errorf("could not extract summary from JIRA ticket: %s", ticket)
	}

	return issue.Fields.Summary, nil
}

// CleanSummary cleans a JIRA summary for use in branch names
func (j *JIRAService) CleanSummary(summary string) string {
	// Convert to lowercase and replace non-alphanumeric chars with hyphens
	cleaned := strings.ToLower(summary)
	invalidChars := regexp.MustCompile(`[^a-z0-9]`)
	cleaned = invalidChars.ReplaceAllString(cleaned, "-")

	// Remove multiple consecutive hyphens
	multipleHyphens := regexp.MustCompile(`-+`)
	cleaned = multipleHyphens.ReplaceAllString(cleaned, "-")

	// Trim hyphens from start and end
	cleaned = strings.Trim(cleaned, "-")

	return cleaned
}

// CreateBranchName creates a branch name from JIRA ticket and summary
func (j *JIRAService) CreateBranchName(ticket, summary string) string {
	if summary == "" {
		return ticket
	}

	cleanSummary := j.CleanSummary(summary)
	if cleanSummary == "" {
		return ticket
	}

	return fmt.Sprintf("%s-%s", ticket, cleanSummary)
}

// CreateCommitMessage creates a commit message with JIRA information
func (j *JIRAService) CreateCommitMessage(commitType, emoji, ticket, summary string) string {
	baseMessage := fmt.Sprintf("%s: %s", commitType, emoji)

	if ticket != "" {
		if summary != "" {
			baseMessage = fmt.Sprintf("%s %s %s", baseMessage, ticket, strings.ToLower(summary))
			// Only add Jira link when we have both ticket and summary (meaning it was successfully fetched)
			if j.ticketLink != "" {
				baseMessage = fmt.Sprintf("%s\n\nJira: %s%s", baseMessage, j.ticketLink, ticket)
			}
		} else {
			baseMessage = fmt.Sprintf("%s %s", baseMessage, ticket)
			// Add Jira link even when we only have ticket (if configured)
			if j.ticketLink != "" {
				baseMessage = fmt.Sprintf("%s\n\nJira: %s%s", baseMessage, j.ticketLink, ticket)
			}
		}
	} else {
		baseMessage = fmt.Sprintf("%s %s", baseMessage, summary)
	}

	return baseMessage
}

// PromptForDescription prompts the user to enter a description for the branch
func (j *JIRAService) PromptForDescription(ctx context.Context, ticket string) (string, error) {
	config := ui.FzfConfig{
		Prompt: fmt.Sprintf("Enter description for %s", ticket),
		Height: "3",
	}

	description, err := ui.RunFzfInput(ctx, config)
	if err != nil {
		return "", fmt.Errorf("failed to get description input: %w", err)
	}

	return strings.TrimSpace(description), nil
}

// GetTicketWithFallback attempts to get JIRA ticket info with fallback to manual input
func (j *JIRAService) GetTicketWithFallback(ctx context.Context, input string) (ticket, summary, branchName string) {
	if j.ValidateTicket(input) {
		// Input looks like a JIRA ticket
		ticket = input
		color.Yellow("Fetching JIRA ticket details...")

		fetchedSummary, err := j.GetSummary(ctx, ticket)
		if err != nil {
			color.Yellow("Could not fetch JIRA summary: %v", err)
			// Prompt user for description instead of using just ticket number
			description, promptErr := j.PromptForDescription(ctx, ticket)
			if promptErr != nil {
				color.Yellow("Warning: Could not get description input: %v", promptErr)
				color.Yellow("Using ticket number as branch name.")
				branchName = ticket
			} else if description != "" {
				// Clean and format the description like a summary
				cleanDescription := j.CleanSummary(description)
				if cleanDescription != "" {
					branchName = fmt.Sprintf("%s-%s", ticket, cleanDescription)
					color.Green("✅ Created branch name: %s", branchName)
				} else {
					color.Yellow("Description could not be formatted, using ticket number as branch name.")
					branchName = ticket
				}
			} else {
				color.Yellow("No description provided, using ticket number as branch name.")
				branchName = ticket
			}
		} else {
			summary = fetchedSummary
			color.Green("✅ JIRA ticket found: %s", summary)
			branchName = j.CreateBranchName(ticket, summary)
		}
	} else {
		// Input doesn't match JIRA pattern, use as branch name directly
		if input != "" {
			color.Yellow("Input doesn't match JIRA pattern. Using as branch name directly.")
			branchName = input
		} else {
			branchName = input
		}
	}

	return ticket, summary, branchName
}
