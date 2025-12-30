package domain

import (
	"path/filepath"
	"time"
)

// Repository represents a Git repository
type Repository struct {
	Path    string    `json:"path"`
	Name    string    `json:"name"`
	Remote  string    `json:"remote,omitempty"`
	Branch  string    `json:"branch,omitempty"`
	LastMod time.Time `json:"last_modified"`
}

// Worktree represents a Git worktree
type Worktree struct {
	Path       string      `json:"path"`
	Branch     string      `json:"branch"`
	Repository *Repository `json:"repository"`
	CreatedAt  time.Time   `json:"created_at"`
}

// Project represents a development project
type Project struct {
	Name        string      `json:"name"`
	Path        string      `json:"path"`
	Repository  *Repository `json:"repository,omitempty"`
	Worktrees   []*Worktree `json:"worktrees,omitempty"`
	PackageType PackageType `json:"package_type"`
	LastUsed    time.Time   `json:"last_used"`
}

// PackageType represents the type of package manager used
type PackageType string

const (
	PackageTypeUnknown PackageType = "unknown"
	PackageTypeNpm     PackageType = "npm"
	PackageTypeYarn    PackageType = "yarn"
	PackageTypePnpm    PackageType = "pnpm"
	PackageTypeGo      PackageType = "go"
	PackageTypeCargo   PackageType = "cargo"
	PackageTypePython  PackageType = "python"
)

// Theme represents a theme configuration
type Theme struct {
	Name        string            `json:"name"`
	DisplayName string            `json:"display_name"`
	Files       map[string]string `json:"files"` // app -> file path
}

// GetName returns the repository name from its path
func (r *Repository) GetName() string {
	if r.Name != "" {
		return r.Name
	}
	return filepath.Base(r.Path)
}

// IsValid checks if the repository is valid
func (r *Repository) IsValid() bool {
	return r.Path != "" && filepath.IsAbs(r.Path)
}

// GetName returns the worktree name (usually branch name)
func (w *Worktree) GetName() string {
	if w.Branch != "" {
		return w.Branch
	}
	return filepath.Base(w.Path)
}

// IsValid checks if the worktree is valid
func (w *Worktree) IsValid() bool {
	return w.Path != "" && filepath.IsAbs(w.Path) && w.Repository != nil
}

// DeletionResult represents the result of a worktree deletion
type DeletionResult struct {
	Path         string `json:"path"`
	UsedFallback bool   `json:"used_fallback"`
	Method       string `json:"method"` // "git" or "directory"
}

// DetectPackageType detects package type from project path
func (p *Project) DetectPackageType() PackageType {
	// This will be implemented to check for package.json, go.mod, Cargo.toml, etc.
	return PackageTypeUnknown
}

// IsValid checks if the project is valid
func (p *Project) IsValid() bool {
	return p.Name != "" && p.Path != "" && filepath.IsAbs(p.Path)
}
