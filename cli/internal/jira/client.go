package jira

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/domain"
	"github.com/jimmy/dotfiles-cli/pkg/errors"
)

// Client provides JIRA operations
type Client interface {
	ValidateTicket(ticketKey string) (*domain.JiraTicket, error)
	GetTicket(ticketKey string) (*domain.JiraTicket, error)
	GenerateBranchName(ticketKey, summary string) string
	IsValidTicketKey(ticketKey string) bool
}

// client implements the JIRA Client interface
type client struct {
	config     *config.Config
	httpClient *http.Client
	baseURL    string
	username   string
	token      string
}

// jiraTicketResponse represents the JIRA API response structure
type jiraTicketResponse struct {
	Key    string `json:"key"`
	Fields struct {
		Summary     string `json:"summary"`
		Description string `json:"description"`
		Status      struct {
			Name string `json:"name"`
		} `json:"status"`
		IssueType struct {
			Name string `json:"name"`
		} `json:"issuetype"`
		Labels     []string `json:"labels"`
		Components []struct {
			Name string `json:"name"`
		} `json:"components"`
	} `json:"fields"`
}

// NewClient creates a new JIRA client
func NewClient(cfg *config.Config) (Client, error) {
	if !cfg.JIRA.Enabled {
		return &noopClient{}, nil
	}

	if cfg.JIRA.BaseURL == "" {
		return nil, errors.NewError(errors.ErrConfigInvalid, "JIRA base URL is required when JIRA is enabled")
	}

	if cfg.JIRA.Token == "" {
		return nil, errors.NewError(errors.ErrConfigInvalid, "JIRA token is required when JIRA is enabled")
	}

	return &client{
		config: cfg,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL:  strings.TrimSuffix(cfg.JIRA.BaseURL, "/"),
		username: cfg.JIRA.Username,
		token:    cfg.JIRA.Token,
	}, nil
}

// IsValidTicketKey validates JIRA ticket key format
func (c *client) IsValidTicketKey(ticketKey string) bool {
	if c.config.JIRA.Pattern == "" {
		// Default JIRA key pattern
		pattern := regexp.MustCompile(`^[A-Z]{2,10}-\d{1,6}$`)
		return pattern.MatchString(ticketKey)
	}

	pattern := regexp.MustCompile(c.config.JIRA.Pattern)
	return pattern.MatchString(ticketKey)
}

// ValidateTicket validates a JIRA ticket exists and is accessible
func (c *client) ValidateTicket(ticketKey string) (*domain.JiraTicket, error) {
	if !c.IsValidTicketKey(ticketKey) {
		return nil, errors.NewInvalidJIRAKeyError(ticketKey)
	}

	return c.GetTicket(ticketKey)
}

// GetTicket fetches ticket information from JIRA API
func (c *client) GetTicket(ticketKey string) (*domain.JiraTicket, error) {
	url := fmt.Sprintf("%s/rest/api/2/issue/%s", c.baseURL, ticketKey)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, errors.NewJIRAError("failed to create request", err)
	}

	// Set authentication
	if c.username != "" {
		req.SetBasicAuth(c.username, c.token)
	} else {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, errors.NewJIRAError("failed to execute request", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 {
		return nil, errors.NewError(errors.ErrJIRATicketNotFound, fmt.Sprintf("JIRA ticket %s not found", ticketKey))
	}

	if resp.StatusCode != 200 {
		return nil, errors.NewJIRAError(fmt.Sprintf("JIRA API returned status %d", resp.StatusCode), nil)
	}

	var jiraResp jiraTicketResponse
	if err := json.NewDecoder(resp.Body).Decode(&jiraResp); err != nil {
		return nil, errors.NewJIRAError("failed to decode response", err)
	}

	// Extract component names
	var components []string
	for _, comp := range jiraResp.Fields.Components {
		components = append(components, comp.Name)
	}

	return &domain.JiraTicket{
		Key:         jiraResp.Key,
		Summary:     jiraResp.Fields.Summary,
		Description: jiraResp.Fields.Description,
		Status:      jiraResp.Fields.Status.Name,
		Type:        jiraResp.Fields.IssueType.Name,
		Labels:      jiraResp.Fields.Labels,
		Components:  components,
	}, nil
}

// GenerateBranchName creates a Git-safe branch name from JIRA ticket
func (c *client) GenerateBranchName(ticketKey, summary string) string {
	// Start with ticket key
	branchName := strings.ToLower(ticketKey)

	// Add cleaned summary if provided
	if summary != "" {
		// Clean the summary: remove special chars, replace spaces with hyphens
		cleanSummary := strings.ToLower(summary)

		// Replace common words and characters
		replacements := map[string]string{
			" ":  "-",
			"_":  "-",
			".":  "-",
			",":  "",
			"'":  "",
			"\"": "",
			"(":  "",
			")":  "",
			"[":  "",
			"]":  "",
			"{":  "",
			"}":  "",
			"/":  "-",
			"\\": "-",
			":":  "-",
			";":  "",
			"!":  "",
			"?":  "",
			"@":  "",
			"#":  "",
			"$":  "",
			"%":  "",
			"^":  "",
			"&":  "",
			"*":  "",
			"+":  "",
			"=":  "",
			"|":  "",
			"`":  "",
			"~":  "",
		}

		for old, new := range replacements {
			cleanSummary = strings.ReplaceAll(cleanSummary, old, new)
		}

		// Remove multiple consecutive hyphens
		for strings.Contains(cleanSummary, "--") {
			cleanSummary = strings.ReplaceAll(cleanSummary, "--", "-")
		}

		// Trim hyphens from start and end
		cleanSummary = strings.Trim(cleanSummary, "-")

		// Limit length to keep branch name reasonable
		if len(cleanSummary) > 50 {
			cleanSummary = cleanSummary[:50]
			// Don't end with a hyphen
			cleanSummary = strings.TrimSuffix(cleanSummary, "-")
		}

		if cleanSummary != "" {
			branchName = fmt.Sprintf("%s-%s", branchName, cleanSummary)
		}
	}

	// Ensure branch name is valid for Git
	branchName = strings.Trim(branchName, "-.")

	// Remove any remaining invalid characters for Git
	invalidChars := regexp.MustCompile(`[^a-zA-Z0-9\-._/]`)
	branchName = invalidChars.ReplaceAllString(branchName, "")

	return branchName
}

// noopClient is used when JIRA is disabled
type noopClient struct{}

func (nc *noopClient) ValidateTicket(ticketKey string) (*domain.JiraTicket, error) {
	return nil, errors.NewError(errors.ErrJIRAConnection, "JIRA integration is disabled")
}

func (nc *noopClient) GetTicket(ticketKey string) (*domain.JiraTicket, error) {
	return nil, errors.NewError(errors.ErrJIRAConnection, "JIRA integration is disabled")
}

func (nc *noopClient) GenerateBranchName(ticketKey, summary string) string {
	// When JIRA is disabled, still provide basic branch name generation
	return strings.ToLower(ticketKey)
}

func (nc *noopClient) IsValidTicketKey(ticketKey string) bool {
	// Basic validation when JIRA is disabled
	pattern := regexp.MustCompile(`^[A-Z]{2,10}-\d{1,6}$`)
	return pattern.MatchString(ticketKey)
}
