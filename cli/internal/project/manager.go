package project

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/jimmy/dotfiles-cli/internal/config"
	"github.com/jimmy/dotfiles-cli/internal/domain"
	"github.com/jimmy/dotfiles-cli/internal/git"
)

// Manager handles project operations
type Manager interface {
	ListProjects(ctx context.Context) ([]*domain.Project, error)
	SelectProject(ctx context.Context, interactive bool) (*domain.Project, error)
	CreateSymlink(project *domain.Project, suffix string) error
	DetectPackageType(projectPath string) domain.PackageType
	SyncProjects(ctx context.Context) error
	GetLastSelectedProject() (*domain.Project, error)
}

// manager implements the Manager interface
type manager struct {
	config    *config.Config
	gitClient git.Client
}

// NewManager creates a new project manager
func NewManager(cfg *config.Config) Manager {
	return &manager{
		config:    cfg,
		gitClient: git.NewClient(),
	}
}

// ListProjects discovers and lists all development projects
func (m *manager) ListProjects(ctx context.Context) ([]*domain.Project, error) {
	// Find all git repositories
	repos, err := m.gitClient.FindRepositories(ctx, m.config.Directories.Programming, m.config.Git.MaxDepth)
	if err != nil {
		return nil, fmt.Errorf("failed to find repositories: %w", err)
	}

	var projects []*domain.Project

	for _, repo := range repos {
		project := &domain.Project{
			Name:        repo.GetName(),
			Path:        repo.Path,
			Repository:  repo,
			PackageType: m.DetectPackageType(repo.Path),
			LastUsed:    repo.LastMod,
		}

		// Find worktrees for this repository
		worktrees, err := m.gitClient.ListWorktrees(ctx, repo.Path)
		if err == nil {
			project.Worktrees = worktrees
		}

		projects = append(projects, project)
	}

	// Sort by last used time (most recent first)
	sort.Slice(projects, func(i, j int) bool {
		return projects[i].LastUsed.After(projects[j].LastUsed)
	})

	return projects, nil
}

// SelectProject provides interactive project selection
func (m *manager) SelectProject(ctx context.Context, interactive bool) (*domain.Project, error) {
	projects, err := m.ListProjects(ctx)
	if err != nil {
		return nil, err
	}

	if len(projects) == 0 {
		return nil, fmt.Errorf("no projects found in %s", m.config.Directories.Programming)
	}

	if !interactive {
		// Return the most recently used project
		return projects[0], nil
	}

	// Try FZF for interactive selection
	selected, err := m.selectProjectWithFZF(projects)
	if err != nil {
		// Fallback to numbered selection
		return m.selectProjectWithNumberedList(projects)
	}

	return selected, nil
}

// CreateSymlink creates a symlink with the specified suffix
func (m *manager) CreateSymlink(project *domain.Project, suffix string) error {
	if !project.IsValid() {
		return fmt.Errorf("invalid project: %v", project)
	}

	// Create symlink name with suffix
	linkName := fmt.Sprintf("%s-%s", project.Name, suffix)
	linkPath := filepath.Join(m.config.Directories.Programming, linkName)

	// Remove existing symlink if it exists
	if _, err := os.Lstat(linkPath); err == nil {
		if err := os.Remove(linkPath); err != nil {
			return fmt.Errorf("failed to remove existing symlink: %w", err)
		}
	}

	// Create new symlink
	if err := os.Symlink(project.Path, linkPath); err != nil {
		return fmt.Errorf("failed to create symlink: %w", err)
	}

	return nil
}

// DetectPackageType identifies the package manager used in a project
func (m *manager) DetectPackageType(projectPath string) domain.PackageType {
	// Check for various package manager files
	packageFiles := map[string]domain.PackageType{
		"package.json":      domain.PackageTypeUnknown, // Need to check lock files
		"pnpm-lock.yaml":    domain.PackageTypePnpm,
		"yarn.lock":         domain.PackageTypeYarn,
		"package-lock.json": domain.PackageTypeNpm,
		"go.mod":            domain.PackageTypeGo,
		"Cargo.toml":        domain.PackageTypeCargo,
		"pyproject.toml":    domain.PackageTypePython,
		"requirements.txt":  domain.PackageTypePython,
		"setup.py":          domain.PackageTypePython,
	}

	// Check files in order of preference
	for file, packageType := range packageFiles {
		if _, err := os.Stat(filepath.Join(projectPath, file)); err == nil {
			// For package.json, need to check lock files to determine exact package manager
			if packageType == domain.PackageTypeUnknown {
				if _, err := os.Stat(filepath.Join(projectPath, "pnpm-lock.yaml")); err == nil {
					return domain.PackageTypePnpm
				}
				if _, err := os.Stat(filepath.Join(projectPath, "yarn.lock")); err == nil {
					return domain.PackageTypeYarn
				}
				if _, err := os.Stat(filepath.Join(projectPath, "package-lock.json")); err == nil {
					return domain.PackageTypeNpm
				}
				// Default to npm if only package.json exists
				return domain.PackageTypeNpm
			}
			return packageType
		}
	}

	return domain.PackageTypeUnknown
}

// SyncProjects updates project metadata and caches
func (m *manager) SyncProjects(ctx context.Context) error {
	projects, err := m.ListProjects(ctx)
	if err != nil {
		return err
	}

	// Update last selection cache
	lastSelectionPath := filepath.Join(m.config.Directories.Home, ".last_project")

	if len(projects) > 0 {
		// Write the most recently used project
		content := projects[0].Path
		if err := os.WriteFile(lastSelectionPath, []byte(content), 0644); err != nil {
			return fmt.Errorf("failed to update last selection cache: %w", err)
		}
	}

	return nil
}

// GetLastSelectedProject returns the last selected project from cache
func (m *manager) GetLastSelectedProject() (*domain.Project, error) {
	lastSelectionPath := filepath.Join(m.config.Directories.Home, ".last_project")

	content, err := os.ReadFile(lastSelectionPath)
	if err != nil {
		return nil, fmt.Errorf("no last selection found")
	}

	projectPath := strings.TrimSpace(string(content))
	if projectPath == "" {
		return nil, fmt.Errorf("empty last selection")
	}

	// Verify project still exists
	if _, err := os.Stat(projectPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("last selected project no longer exists: %s", projectPath)
	}

	// Create project from path
	repo, err := m.gitClient.OpenRepository(projectPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open repository: %w", err)
	}

	return &domain.Project{
		Name:        repo.GetName(),
		Path:        repo.Path,
		Repository:  repo,
		PackageType: m.DetectPackageType(repo.Path),
		LastUsed:    time.Now(),
	}, nil
}

// selectProjectWithFZF uses fzf for interactive project selection
func (m *manager) selectProjectWithFZF(projects []*domain.Project) (*domain.Project, error) {
	// Check if fzf is available
	if _, err := exec.LookPath("fzf"); err != nil {
		return nil, fmt.Errorf("fzf not found: %w", err)
	}

	// Prepare project list for FZF
	var buf bytes.Buffer
	projectMap := make(map[string]*domain.Project)

	for _, proj := range projects {
		line := fmt.Sprintf("%s (%s)", proj.Name, proj.Path)
		buf.WriteString(line + "\n")
		projectMap[line] = proj
	}

	// Run FZF
	cmd := exec.Command("fzf", "--prompt=Select project: ", "--height=40%", "--border")
	cmd.Stdin = strings.NewReader(buf.String())

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("fzf selection cancelled or failed: %w", err)
	}

	// Parse FZF output
	selected := strings.TrimSpace(output.String())
	if selected == "" {
		return nil, fmt.Errorf("no selection made")
	}

	// Find the selected project
	if project, ok := projectMap[selected]; ok {
		return project, nil
	}

	return nil, fmt.Errorf("selected project not found: %s", selected)
}

// selectProjectWithNumberedList provides fallback numbered selection
func (m *manager) selectProjectWithNumberedList(projects []*domain.Project) (*domain.Project, error) {
	fmt.Println("\nAvailable projects:")
	for i, proj := range projects {
		fmt.Printf("%d. %s (%s)\n", i+1, proj.Name, proj.Path)
	}

	fmt.Printf("Enter project number (1-%d): ", len(projects))

	var input string
	if _, err := fmt.Scanln(&input); err != nil {
		return nil, fmt.Errorf("failed to read input: %w", err)
	}

	selection, err := strconv.Atoi(strings.TrimSpace(input))
	if err != nil {
		return nil, fmt.Errorf("invalid number: %s", input)
	}

	if selection < 1 || selection > len(projects) {
		return nil, fmt.Errorf("selection out of range: %d (valid: 1-%d)", selection, len(projects))
	}

	return projects[selection-1], nil
}
