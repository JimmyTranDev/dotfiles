package jira

import (
	"fmt"
	"testing"
)

func TestJIRAService_ValidateTicket(t *testing.T) {
	service, err := NewJIRAService(`^[A-Z]+-[0-9]+$`, "https://example.atlassian.net/browse/")
	if err != nil {
		t.Fatalf("Failed to create JIRA service: %v", err)
	}

	tests := []struct {
		name     string
		ticket   string
		expected bool
	}{
		{"valid ticket uppercase", "ABC-123", true},
		{"valid ticket mixed case", "SB-456", true},
		{"invalid lowercase", "abc-123", false},
		{"invalid no hyphen", "ABC123", false},
		{"invalid no number", "ABC-", false},
		{"invalid no letters", "-123", false},
		{"empty string", "", false},
		{"invalid format", "not-a-ticket", false},
		{"multi digit project", "PROJECT-999", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := service.ValidateTicket(tt.ticket)
			if result != tt.expected {
				t.Errorf("ValidateTicket(%q) = %v, expected %v", tt.ticket, result, tt.expected)
			}
		})
	}
}

func TestJIRAService_CleanSummary(t *testing.T) {
	service, err := NewJIRAService(`^[A-Z]+-[0-9]+$`, "")
	if err != nil {
		t.Fatalf("Failed to create JIRA service: %v", err)
	}

	tests := []struct {
		name     string
		summary  string
		expected string
	}{
		{"simple text", "Fix user login", "fix-user-login"},
		{"with special chars", "Fix user's login & logout", "fix-user-s-login-logout"},
		{"multiple spaces", "Fix  user   login", "fix-user-login"},
		{"leading/trailing spaces", " Fix user login ", "fix-user-login"},
		{"mixed case", "Fix User Login", "fix-user-login"},
		{"numbers", "Fix bug 123", "fix-bug-123"},
		{"already clean", "fix-user-login", "fix-user-login"},
		{"add user authentication", "Add User Authentication", "add-user-authentication"},
		{"implement payment system", "Implement Payment System", "implement-payment-system"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := service.CleanSummary(tt.summary)
			if result != tt.expected {
				t.Errorf("CleanSummary(%q) = %q, expected %q", tt.summary, result, tt.expected)
			}
		})
	}
}

func TestJIRAService_CreateBranchName(t *testing.T) {
	service, err := NewJIRAService(`^[A-Z]+-[0-9]+$`, "")
	if err != nil {
		t.Fatalf("Failed to create JIRA service: %v", err)
	}

	tests := []struct {
		name     string
		ticket   string
		summary  string
		expected string
	}{
		{"with summary", "ABC-123", "Fix user login", "ABC-123-fix-user-login"},
		{"without summary", "ABC-123", "", "ABC-123"},
		{"empty summary after cleaning", "ABC-123", "!!!", "ABC-123"},
		{"complex summary", "SB-456", "Update user's profile & settings", "SB-456-update-user-s-profile-settings"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := service.CreateBranchName(tt.ticket, tt.summary)
			if result != tt.expected {
				t.Errorf("CreateBranchName(%q, %q) = %q, expected %q", tt.ticket, tt.summary, result, tt.expected)
			}
		})
	}
}

func TestJIRAService_CreateCommitMessage(t *testing.T) {
	tests := []struct {
		name       string
		ticketLink string
		commitType string
		emoji      string
		ticket     string
		summary    string
		expected   string
	}{
		{
			"with JIRA link",
			"https://example.atlassian.net/browse/",
			"feat",
			"✨",
			"ABC-123",
			"Fix user login",
			"feat: ✨ ABC-123 fix user login\n\nJira: https://example.atlassian.net/browse/ABC-123",
		},
		{
			"without JIRA link",
			"",
			"fix",
			"🐛",
			"ABC-123",
			"Fix user login",
			"fix: 🐛 ABC-123 fix user login",
		},
		{
			"no ticket",
			"",
			"feat",
			"✨",
			"",
			"Add new feature",
			"feat: ✨ Add new feature",
		},
		{
			"ticket without summary",
			"https://example.atlassian.net/browse/",
			"feat",
			"✨",
			"ABC-123",
			"",
			"feat: ✨ ABC-123\n\nJira: https://example.atlassian.net/browse/ABC-123",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			service, err := NewJIRAService(`^[A-Z]+-[0-9]+$`, tt.ticketLink)
			if err != nil {
				t.Fatalf("Failed to create JIRA service: %v", err)
			}

			result := service.CreateCommitMessage(tt.commitType, tt.emoji, tt.ticket, tt.summary)
			if result != tt.expected {
				t.Errorf("CreateCommitMessage() = %q, expected %q", result, tt.expected)
			}
		})
	}
}

func TestJIRAService_CreateBranchNameWithDescription(t *testing.T) {
	service, err := NewJIRAService(`^[A-Z]+-[0-9]+$`, "")
	if err != nil {
		t.Fatalf("Failed to create JIRA service: %v", err)
	}

	tests := []struct {
		name        string
		ticket      string
		description string
		expected    string
	}{
		{"simple description", "BW-10050", "Add User Authentication", "BW-10050-add-user-authentication"},
		{"complex description", "ABC-123", "Implement Payment System & Validation", "ABC-123-implement-payment-system-validation"},
		{"description with numbers", "XYZ-456", "Fix Bug 123 in Login", "XYZ-456-fix-bug-123-in-login"},
		{"description with special chars", "TEST-789", "Update User's Profile & Settings", "TEST-789-update-user-s-profile-settings"},
		{"empty description", "BW-10050", "", "BW-10050"},
		{"whitespace description", "BW-10050", "   ", "BW-10050"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Simulate the scenario where JIRA fetch fails and we use manual description
			cleanDescription := service.CleanSummary(tt.description)
			var branchName string
			if cleanDescription != "" {
				branchName = fmt.Sprintf("%s-%s", tt.ticket, cleanDescription)
			} else {
				branchName = tt.ticket
			}

			if branchName != tt.expected {
				t.Errorf("CreateBranchName with description %q = %q, expected %q", tt.description, branchName, tt.expected)
			}
		})
	}
}
