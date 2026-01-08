package git

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"

	"github.com/jimmy/worktree-cli/internal/domain"
	"github.com/jimmy/worktree-cli/pkg/errors"
)

// Client provides Git operations
type Client interface {
	// Repository operations
	OpenRepository(path string) (*domain.Repository, error)
	CloneRepository(ctx context.Context, url, path string) (*domain.Repository, error)
	FindRepositories(ctx context.Context, baseDir string, maxDepth int) ([]*domain.Repository, error)

	// Worktree operations
	CreateWorktree(ctx context.Context, repoPath, branch, worktreePath string) (*domain.Worktree, error)
	CreateWorktreeFromBranch(ctx context.Context, repoPath, branch, baseBranch, worktreePath string) (*domain.Worktree, error)
	ListWorktrees(ctx context.Context, repoPath string) ([]*domain.Worktree, error)
	DeleteWorktree(ctx context.Context, worktreePath string) (*domain.DeletionResult, error)
	PruneWorktrees(ctx context.Context, repoPath string) error

	// Branch operations
	ListBranches(ctx context.Context, repoPath string) ([]string, error)
	ListRemoteBranches(ctx context.Context, repoPath string) ([]string, error)
	CreateBranch(ctx context.Context, repoPath, branchName, baseBranch string) error
	DeleteBranch(ctx context.Context, repoPath, branchName string, force bool) error
	CheckoutBranch(ctx context.Context, repoPath, branchName string) error
	CheckoutRemoteBranch(ctx context.Context, repoPath, remoteBranch, worktreePath string) (*domain.Worktree, error)
	FindMainBranch(ctx context.Context, repoPath string) (string, error)
	FetchOrigin(ctx context.Context, repoPath string) error

	// Commit operations
	CreateEmptyCommit(ctx context.Context, repoPath, message string) error

	// Status operations
	GetStatus(ctx context.Context, repoPath string) (*GitStatus, error)
	IsClean(ctx context.Context, repoPath string) (bool, error)
}

// GitStatus represents the status of a git repository
type GitStatus struct {
	Branch    string   `json:"branch"`
	Modified  []string `json:"modified"`
	Added     []string `json:"added"`
	Deleted   []string `json:"deleted"`
	Untracked []string `json:"untracked"`
	IsClean   bool     `json:"is_clean"`
	AheadBy   int      `json:"ahead_by"`
	BehindBy  int      `json:"behind_by"`
}

// client implements the Git Client interface
type client struct {
	mu sync.RWMutex
}

// runGitCommandWithOutput executes a git command with proper output limiting and timeout handling
func (c *client) runGitCommandWithOutput(ctx context.Context, cmd *exec.Cmd) (string, error) {
	// Set up output capture with size limits (1MB max to prevent memory exhaustion)
	const maxOutputSize = 1024 * 1024
	var stdout, stderr bytes.Buffer

	cmd.Stdout = &limitedWriter{Writer: &stdout, Limit: maxOutputSize}
	cmd.Stderr = &limitedWriter{Writer: &stderr, Limit: maxOutputSize}

	// Prevent git from prompting for user input by setting stdin to null
	cmd.Stdin = nil

	// Set environment variables to prevent interactive prompts
	if cmd.Env == nil {
		cmd.Env = os.Environ()
	}
	cmd.Env = append(cmd.Env,
		"GIT_TERMINAL_PROMPT=0", // Disable terminal prompts
		"GIT_ASKPASS=true",      // Use true as askpass to fail fast on auth
		"SSH_ASKPASS=true",      // Disable SSH password prompts
	)

	// Create a timeout context if none exists or if the context has no timeout
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
	} else {
		// Check if context already has a deadline, if not add one
		if _, hasDeadline := ctx.Deadline(); !hasDeadline {
			var cancel context.CancelFunc
			ctx, cancel = context.WithTimeout(ctx, 30*time.Second)
			defer cancel()
		}
	}

	// Update command context
	cmd = exec.CommandContext(ctx, cmd.Args[0], cmd.Args[1:]...)
	cmd.Stdout = &limitedWriter{Writer: &stdout, Limit: maxOutputSize}
	cmd.Stderr = &limitedWriter{Writer: &stderr, Limit: maxOutputSize}
	cmd.Stdin = nil
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	if cmd.Dir == "" {
		// Preserve the working directory from the original command
		for i, arg := range cmd.Args {
			if arg == "-C" && i+1 < len(cmd.Args) {
				cmd.Dir = cmd.Args[i+1]
				// Remove -C and path from args since we set Dir
				cmd.Args = append(cmd.Args[:i], cmd.Args[i+2:]...)
				break
			}
		}
	}

	// Execute with proper cleanup on context cancellation
	if err := cmd.Run(); err != nil {
		output := fmt.Sprintf("stdout: %s, stderr: %s", stdout.String(), stderr.String())

		// Check if context was cancelled (timeout or user interruption)
		if ctx.Err() != nil {
			return output, fmt.Errorf("git command timed out or was cancelled: %w", ctx.Err())
		}

		return output, err
	}

	return stdout.String(), nil
}

// limitedWriter prevents unlimited memory consumption from command output
type limitedWriter struct {
	io.Writer
	Limit   int
	Written int
}

func (lw *limitedWriter) Write(data []byte) (int, error) {
	if lw.Written >= lw.Limit {
		return 0, fmt.Errorf("output size limit exceeded (%d bytes)", lw.Limit)
	}

	remaining := lw.Limit - lw.Written
	if len(data) > remaining {
		data = data[:remaining]
	}

	n, err := lw.Writer.Write(data)
	lw.Written += n
	return n, err
}

// NewClient creates a new Git client
func NewClient() Client {
	return &client{}
}

// OpenRepository opens an existing git repository
func (c *client) OpenRepository(path string) (*domain.Repository, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if !filepath.IsAbs(path) {
		return nil, errors.NewError(errors.ErrInvalidInput, "repository path must be absolute")
	}

	repo, err := git.PlainOpen(path)
	if err != nil {
		return nil, errors.NewGitError("failed to open repository", err)
	}

	head, err := repo.Head()
	if err != nil {
		return nil, errors.NewGitError("failed to get repository head", err)
	}

	// Get repository info

	// Get remote URL if available
	remotes, err := repo.Remotes()
	var remoteURL string
	if err == nil && len(remotes) > 0 {
		if urls := remotes[0].Config().URLs; len(urls) > 0 {
			remoteURL = urls[0]
		}
	}

	// Get file info for last modified time
	info, err := os.Stat(path)
	var lastMod time.Time
	if err == nil {
		lastMod = info.ModTime()
	} else {
		// If we can't get file info, use current time
		lastMod = time.Now()
	}

	return &domain.Repository{
		Path:    path,
		Name:    filepath.Base(path),
		Remote:  remoteURL,
		Branch:  head.Name().Short(),
		LastMod: lastMod,
	}, nil
}

// CloneRepository clones a repository to the specified path
func (c *client) CloneRepository(ctx context.Context, url, path string) (*domain.Repository, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(path) {
		return nil, errors.NewError(errors.ErrInvalidInput, "clone path must be absolute")
	}

	// Check if directory already exists
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		return nil, errors.NewError(errors.ErrInvalidInput, "directory already exists")
	}

	// Clone repository
	repo, err := git.PlainCloneContext(ctx, path, false, &git.CloneOptions{
		URL:      url,
		Progress: os.Stdout,
	})
	if err != nil {
		return nil, errors.NewGitError("failed to clone repository", err)
	}

	head, err := repo.Head()
	if err != nil {
		return nil, errors.NewGitError("failed to get repository head after clone", err)
	}

	return &domain.Repository{
		Path:   path,
		Name:   filepath.Base(path),
		Remote: url,
		Branch: head.Name().Short(),
	}, nil
}

// FindRepositories finds Git repositories in the given directory
func (c *client) FindRepositories(ctx context.Context, baseDir string, maxDepth int) ([]*domain.Repository, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if !filepath.IsAbs(baseDir) {
		return nil, errors.NewError(errors.ErrInvalidInput, "base directory must be absolute")
	}

	var repositories []*domain.Repository

	err := filepath.Walk(baseDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip directories we can't access
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		// Check depth limit
		relPath, _ := filepath.Rel(baseDir, path)
		depth := strings.Count(relPath, string(filepath.Separator))
		if depth > maxDepth {
			return filepath.SkipDir
		}

		// Check if this is a Git repository
		if info.IsDir() && info.Name() == ".git" {
			repoPath := filepath.Dir(path)

			// Try to open repository
			if repo, err := c.OpenRepository(repoPath); err == nil {
				repositories = append(repositories, repo)
			}

			return filepath.SkipDir // Don't recurse into .git directories
		}

		return nil
	})

	if err != nil && err != context.Canceled {
		return nil, errors.NewGitError("failed to search for repositories", err)
	}

	return repositories, nil
}

// CreateWorktree creates a new Git worktree
func (c *client) CreateWorktree(ctx context.Context, repoPath, branch, worktreePath string) (*domain.Worktree, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(repoPath) || !filepath.IsAbs(worktreePath) {
		return nil, errors.NewError(errors.ErrInvalidInput, "paths must be absolute")
	}

	// Check if worktree already exists
	if _, err := os.Stat(worktreePath); !os.IsNotExist(err) {
		return nil, errors.NewWorktreeExistsError(worktreePath)
	}

	// We'll use command line git for worktree creation as go-git doesn't fully support worktrees yet
	// Use -b flag to create new branch from current main branch
	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "worktree", "add", "-b", branch, worktreePath)

	// Limit output size to prevent memory exhaustion and add proper error handling
	output, err := c.runGitCommandWithOutput(ctx, cmd)
	if err != nil {
		return nil, errors.NewGitError(fmt.Sprintf("failed to create worktree: %s", output), err)
	}

	// Open repository to get information
	mainRepo, err := c.OpenRepository(repoPath)
	if err != nil {
		return nil, errors.NewGitError("failed to open main repository", err)
	}

	return &domain.Worktree{
		Path:       worktreePath,
		Branch:     branch,
		Repository: mainRepo,
	}, nil
}

// CreateWorktreeFromBranch creates a new Git worktree from a specific base branch
func (c *client) CreateWorktreeFromBranch(ctx context.Context, repoPath, branch, baseBranch, worktreePath string) (*domain.Worktree, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(repoPath) || !filepath.IsAbs(worktreePath) {
		return nil, errors.NewError(errors.ErrInvalidInput, "paths must be absolute")
	}

	// Check if worktree already exists
	if _, err := os.Stat(worktreePath); !os.IsNotExist(err) {
		return nil, errors.NewWorktreeExistsError(worktreePath)
	}

	// Ensure we have a timeout context
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
	} else if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 30*time.Second)
		defer cancel()
	}

	// Create worktree with new branch from base branch, matching the shell script behavior exactly
	// Note: We skip the fetch operation to avoid hanging on authentication/network issues
	// The bash script works without explicit fetch, so we follow the same pattern
	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "worktree", "add", "-b", branch, worktreePath, baseBranch)

	// Set environment to prevent interactive prompts
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	cmd.Stdin = nil // Prevent waiting for stdin input

	// Use simple execution instead of runGitCommandWithOutput to avoid complexity
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Provide more detailed error information
		return nil, errors.NewGitError(fmt.Sprintf("failed to create worktree from branch %s: %s", baseBranch, string(output)), err)
	}

	// Simplified repository creation to avoid potential hangs with go-git library
	// We only need basic info for the worktree creation, similar to the bash script approach
	mainRepo := &domain.Repository{
		Path:    repoPath,
		Name:    filepath.Base(repoPath),
		Branch:  baseBranch,
		LastMod: time.Now(),
	}

	return &domain.Worktree{
		Path:       worktreePath,
		Branch:     branch,
		Repository: mainRepo,
	}, nil
}

// ListWorktrees lists all worktrees for a repository
func (c *client) ListWorktrees(ctx context.Context, repoPath string) ([]*domain.Worktree, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if !filepath.IsAbs(repoPath) {
		return nil, errors.NewError(errors.ErrInvalidInput, "repository path must be absolute")
	}

	// Use git command to list worktrees
	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "worktree", "list", "--porcelain")
	output, err := cmd.Output()
	if err != nil {
		return nil, errors.NewGitError("failed to list worktrees", err)
	}

	// Parse git worktree output
	var worktrees []*domain.Worktree
	lines := strings.Split(string(output), "\n")

	var currentWorktree *domain.Worktree
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			if currentWorktree != nil {
				worktrees = append(worktrees, currentWorktree)
				currentWorktree = nil
			}
			continue
		}

		if strings.HasPrefix(line, "worktree ") {
			path := strings.TrimPrefix(line, "worktree ")

			// Get repository information
			repo, err := c.OpenRepository(repoPath)
			if err != nil {
				continue // Skip if we can't open the repository
			}

			currentWorktree = &domain.Worktree{
				Path:       path,
				Repository: repo,
			}
		} else if strings.HasPrefix(line, "branch ") && currentWorktree != nil {
			branch := strings.TrimPrefix(line, "branch ")
			currentWorktree.Branch = strings.TrimPrefix(branch, "refs/heads/")
		}
	}

	// Add the last worktree if exists
	if currentWorktree != nil {
		worktrees = append(worktrees, currentWorktree)
	}

	return worktrees, nil
}

// DeleteWorktree deletes a Git worktree and its associated branch
func (c *client) DeleteWorktree(ctx context.Context, worktreePath string) (*domain.DeletionResult, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(worktreePath) {
		return nil, errors.NewError(errors.ErrInvalidInput, "worktree path must be absolute")
	}

	// Note: We don't check if the directory exists because the worktree might be
	// referenced in Git but the directory might have been manually deleted.
	// This is common when directories are cleaned up but Git references remain.

	result := &domain.DeletionResult{
		Path:          worktreePath,
		UsedFallback:  false,
		Method:        "git",
		BranchDeleted: false,
	}

	// Create a timeout context for git operations (10 seconds max)
	gitCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	// Get branch name and repository path before deletion
	var branchName string
	var repoPath string

	// First, try to get the branch from git status in the worktree
	cmd := exec.CommandContext(gitCtx, "git", "-C", worktreePath, "branch", "--show-current")
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	if output, err := cmd.Output(); err == nil {
		branchName = strings.TrimSpace(string(output))
		result.Branch = branchName
	}

	// Try to get the repository path from the worktree
	cmd = exec.CommandContext(gitCtx, "git", "-C", worktreePath, "rev-parse", "--git-common-dir")
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	if output, err := cmd.Output(); err == nil {
		gitCommonDir := strings.TrimSpace(string(output))
		if filepath.IsAbs(gitCommonDir) {
			repoPath = filepath.Dir(gitCommonDir)
		} else {
			// Relative path, resolve it
			absPath, err := filepath.Abs(filepath.Join(worktreePath, gitCommonDir))
			if err == nil {
				repoPath = filepath.Dir(absPath)
			}
		}
	}

	// If we can't get repo path from the worktree, try to find it through worktree list
	if repoPath == "" {
		// This is more complex - we need to find which repository owns this worktree
		// We'll try common parent directories to find a .git folder
		parentDir := filepath.Dir(worktreePath)
		for i := 0; i < 5; i++ { // Limit search depth
			testRepoPath := filepath.Join(parentDir, "..")
			if testRepoPath == parentDir {
				break // Reached root
			}
			parentDir = testRepoPath

			if _, err := os.Stat(filepath.Join(parentDir, ".git")); err == nil {
				// Found a potential repository
				cmd := exec.CommandContext(gitCtx, "git", "-C", parentDir, "worktree", "list")
				cmd.Env = append(os.Environ(),
					"GIT_TERMINAL_PROMPT=0",
					"GIT_ASKPASS=true",
					"SSH_ASKPASS=true",
				)
				if output, err := cmd.Output(); err == nil {
					if strings.Contains(string(output), worktreePath) {
						repoPath = parentDir
						break
					}
				}
			}
		}
	}

	// Check if the directory exists
	dirExists := true
	if _, err := os.Stat(worktreePath); os.IsNotExist(err) {
		dirExists = false
	}

	// First try to use git command to remove worktree (the proper way)
	cmd = exec.CommandContext(gitCtx, "git", "worktree", "remove", worktreePath)
	if !dirExists {
		// If directory doesn't exist, use --force flag to remove the reference anyway
		cmd = exec.CommandContext(gitCtx, "git", "worktree", "remove", "--force", worktreePath)
	}
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)

	if output, err := cmd.CombinedOutput(); err != nil {
		// Check if this is a timeout error first
		if gitCtx.Err() == context.DeadlineExceeded {
			// Git command timed out, use fallback method
			if dirExists {
				if removeErr := os.RemoveAll(worktreePath); removeErr != nil {
					return nil, errors.NewError(errors.ErrGitOperation,
						fmt.Sprintf("git worktree remove timed out and directory removal failed: %v", removeErr))
				}
				result.UsedFallback = true
				result.Method = "directory"
			} else {
				// Directory doesn't exist, but git reference cleanup failed
				result.UsedFallback = true
				result.Method = "reference-cleanup-failed"
			}
		} else {
			// Check if the error is due to missing git repository context or worktree corruption
			outputStr := string(output)
			if strings.Contains(outputStr, "not a git repository") ||
				strings.Contains(outputStr, "fatal: not a git repository") ||
				strings.Contains(outputStr, "not in a git directory") ||
				strings.Contains(outputStr, ".git' does not exist") ||
				strings.Contains(outputStr, "validation failed, cannot remove working tree") ||
				strings.Contains(outputStr, "is not a working tree") ||
				strings.Contains(outputStr, "not a working tree") {

				// Fallback: remove the directory directly since git context is lost
				if dirExists {
					if removeErr := os.RemoveAll(worktreePath); removeErr != nil {
						return nil, errors.NewError(errors.ErrGitOperation,
							fmt.Sprintf("git worktree remove failed and directory removal also failed: git error: %s, remove error: %v",
								outputStr, removeErr))
					}
				}
				// Successfully cleaned up (either removed directory or directory didn't exist)
				result.UsedFallback = true
				result.Method = "reference-cleanup"
			} else {
				// For other git errors, return the original git error
				return nil, errors.NewGitError(fmt.Sprintf("failed to remove worktree: %s", outputStr), err)
			}
		}
	}

	// Now try to delete the associated branch if we have the information
	if branchName != "" && repoPath != "" && branchName != "main" && branchName != "master" && branchName != "develop" {
		// Don't delete main branches
		if err := c.DeleteBranch(ctx, repoPath, branchName, false); err != nil {
			// If regular delete fails, try force delete
			if strings.Contains(err.Error(), "not fully merged") {
				if forceErr := c.DeleteBranch(ctx, repoPath, branchName, true); forceErr != nil {
					result.BranchDeleteError = fmt.Sprintf("failed to delete branch '%s': %v", branchName, forceErr)
				} else {
					result.BranchDeleted = true
				}
			} else {
				result.BranchDeleteError = fmt.Sprintf("failed to delete branch '%s': %v", branchName, err)
			}
		} else {
			result.BranchDeleted = true
		}
	}

	return result, nil
}

// PruneWorktrees removes references to worktrees that no longer exist
func (c *client) PruneWorktrees(ctx context.Context, repoPath string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(repoPath) {
		return errors.NewError(errors.ErrInvalidInput, "repository path must be absolute")
	}

	// Check if repository exists
	if _, err := os.Stat(repoPath); os.IsNotExist(err) {
		return errors.NewError(errors.ErrInvalidRepository, fmt.Sprintf("repository not found at %s", repoPath))
	}

	// Use git worktree prune command to clean up stale references
	cmd := exec.CommandContext(ctx, "git", "worktree", "prune")
	cmd.Dir = repoPath

	// Set up environment to prevent interactive prompts
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GCM_INTERACTIVE=never",
	)

	if output, err := cmd.CombinedOutput(); err != nil {
		return errors.NewGitError(fmt.Sprintf("failed to prune worktrees: %s", string(output)), err)
	}

	return nil
}

// ListRemoteBranches lists all remote branches for a repository
func (c *client) ListRemoteBranches(ctx context.Context, repoPath string) ([]string, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if !filepath.IsAbs(repoPath) {
		return nil, errors.NewError(errors.ErrInvalidInput, "repository path must be absolute")
	}

	// Ensure we have a timeout context
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
	} else if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 30*time.Second)
		defer cancel()
	}

	// Use git command to list remote branches
	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "branch", "-r")
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	cmd.Stdin = nil

	output, err := cmd.Output()
	if err != nil {
		return nil, errors.NewGitError("failed to list remote branches", err)
	}

	var branches []string
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.Contains(line, "HEAD ->") {
			continue
		}

		// Remove "origin/" prefix if present
		if strings.HasPrefix(line, "origin/") {
			branch := strings.TrimPrefix(line, "origin/")
			if branch != "" {
				branches = append(branches, branch)
			}
		} else if !strings.Contains(line, "/") {
			// Local tracking branches without remote prefix
			branches = append(branches, line)
		}
	}

	return branches, nil
}

// CheckoutRemoteBranch creates a worktree from a remote branch
func (c *client) CheckoutRemoteBranch(ctx context.Context, repoPath, remoteBranch, worktreePath string) (*domain.Worktree, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(repoPath) || !filepath.IsAbs(worktreePath) {
		return nil, errors.NewError(errors.ErrInvalidInput, "paths must be absolute")
	}

	// Check if worktree directory already exists
	if _, err := os.Stat(worktreePath); !os.IsNotExist(err) {
		return nil, errors.NewWorktreeExistsError(worktreePath)
	}

	// Ensure we have a timeout context
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
	} else if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 2*time.Minute)
		defer cancel()
	}

	// First fetch to ensure we have the latest remote refs
	if err := c.FetchOrigin(ctx, repoPath); err != nil {
		// Don't fail if fetch fails - proceed with what we have
		// This matches the shell script behavior
	}

	// Check if local branch already exists for this remote branch
	localBranch := remoteBranch
	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "show-ref", "--verify", "--quiet", "refs/heads/"+localBranch)
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)

	var worktreeCmd *exec.Cmd
	if cmd.Run() == nil {
		// Local branch exists, create worktree from it
		worktreeCmd = exec.CommandContext(ctx, "git", "-C", repoPath, "worktree", "add", worktreePath, localBranch)
	} else {
		// Local branch doesn't exist, create it from remote
		worktreeCmd = exec.CommandContext(ctx, "git", "-C", repoPath, "worktree", "add", "-b", localBranch, worktreePath, "origin/"+remoteBranch)
	}

	worktreeCmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	worktreeCmd.Stdin = nil

	output, err := worktreeCmd.CombinedOutput()
	if err != nil {
		return nil, errors.NewGitError(fmt.Sprintf("failed to create worktree from remote branch %s: %s", remoteBranch, string(output)), err)
	}

	// Create repository info
	mainRepo := &domain.Repository{
		Path:    repoPath,
		Name:    filepath.Base(repoPath),
		Branch:  localBranch,
		LastMod: time.Now(),
	}

	return &domain.Worktree{
		Path:       worktreePath,
		Branch:     localBranch,
		Repository: mainRepo,
		CreatedAt:  time.Now(),
	}, nil
}

// FetchOrigin fetches the latest changes from origin
func (c *client) FetchOrigin(ctx context.Context, repoPath string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(repoPath) {
		return errors.NewError(errors.ErrInvalidInput, "repository path must be absolute")
	}

	// Ensure we have a timeout context
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 1*time.Minute)
		defer cancel()
	} else if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 1*time.Minute)
		defer cancel()
	}

	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "fetch", "origin")
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	cmd.Stdin = nil

	output, err := cmd.CombinedOutput()
	if err != nil {
		return errors.NewGitError(fmt.Sprintf("failed to fetch from origin: %s", string(output)), err)
	}

	return nil
}

func (c *client) ListBranches(ctx context.Context, repoPath string) ([]string, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	repo, err := git.PlainOpen(repoPath)
	if err != nil {
		return nil, errors.NewGitError("failed to open repository", err)
	}

	refs, err := repo.References()
	if err != nil {
		return nil, errors.NewGitError("failed to get references", err)
	}

	var branches []string
	err = refs.ForEach(func(ref *plumbing.Reference) error {
		if ref.Name().IsBranch() {
			branches = append(branches, ref.Name().Short())
		}
		return nil
	})

	if err != nil {
		return nil, errors.NewGitError("failed to iterate references", err)
	}

	return branches, nil
}

// CreateBranch creates a new branch
func (c *client) CreateBranch(ctx context.Context, repoPath, branchName, baseBranch string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	repo, err := git.PlainOpen(repoPath)
	if err != nil {
		return errors.NewGitError("failed to open repository", err)
	}

	worktree, err := repo.Worktree()
	if err != nil {
		return errors.NewGitError("failed to get worktree", err)
	}

	// Get base branch reference
	baseBranchRef := plumbing.NewBranchReferenceName(baseBranch)
	baseRef, err := repo.Reference(baseBranchRef, true)
	if err != nil {
		return errors.NewGitError("failed to find base branch", err)
	}

	// Create new branch
	newBranchRef := plumbing.NewBranchReferenceName(branchName)
	err = repo.Storer.SetReference(plumbing.NewHashReference(newBranchRef, baseRef.Hash()))
	if err != nil {
		return errors.NewGitError("failed to create branch", err)
	}

	// Checkout new branch
	err = worktree.Checkout(&git.CheckoutOptions{
		Branch: newBranchRef,
	})
	if err != nil {
		return errors.NewGitError("failed to checkout new branch", err)
	}

	return nil
}

// DeleteBranch deletes a branch from the repository
func (c *client) DeleteBranch(ctx context.Context, repoPath, branchName string, force bool) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(repoPath) {
		return errors.NewError(errors.ErrInvalidInput, "repository path must be absolute")
	}

	// Ensure we have a timeout context
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
	} else if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 15*time.Second)
		defer cancel()
	}

	// Choose the appropriate flag for deletion
	flag := "-d" // Regular delete (safe)
	if force {
		flag = "-D" // Force delete (ignores merge status)
	}

	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "branch", flag, branchName)

	// Set environment to prevent interactive prompts
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	cmd.Stdin = nil

	output, err := cmd.CombinedOutput()
	if err != nil {
		outputStr := string(output)
		// Check for common errors and provide better messages
		if strings.Contains(outputStr, "not found") || strings.Contains(outputStr, "not a valid branch name") {
			return errors.NewError(errors.ErrInvalidInput, fmt.Sprintf("branch '%s' not found", branchName))
		}
		if strings.Contains(outputStr, "not fully merged") {
			return errors.NewError(errors.ErrGitOperation, fmt.Sprintf("branch '%s' is not fully merged; use force delete if you're sure", branchName))
		}
		return errors.NewGitError(fmt.Sprintf("failed to delete branch '%s': %s", branchName, outputStr), err)
	}

	return nil
}

// CheckoutBranch checks out an existing branch
func (c *client) CheckoutBranch(ctx context.Context, repoPath, branchName string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	repo, err := git.PlainOpen(repoPath)
	if err != nil {
		return errors.NewGitError("failed to open repository", err)
	}

	worktree, err := repo.Worktree()
	if err != nil {
		return errors.NewGitError("failed to get worktree", err)
	}

	branchRef := plumbing.NewBranchReferenceName(branchName)
	err = worktree.Checkout(&git.CheckoutOptions{
		Branch: branchRef,
	})
	if err != nil {
		return errors.NewGitError("failed to checkout branch", err)
	}

	return nil
}

// GetStatus gets the current status of a repository
func (c *client) GetStatus(ctx context.Context, repoPath string) (*GitStatus, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	repo, err := git.PlainOpen(repoPath)
	if err != nil {
		return nil, errors.NewGitError("failed to open repository", err)
	}

	worktree, err := repo.Worktree()
	if err != nil {
		return nil, errors.NewGitError("failed to get worktree", err)
	}

	status, err := worktree.Status()
	if err != nil {
		return nil, errors.NewGitError("failed to get status", err)
	}

	head, err := repo.Head()
	if err != nil {
		return nil, errors.NewGitError("failed to get head", err)
	}

	gitStatus := &GitStatus{
		Branch:  head.Name().Short(),
		IsClean: status.IsClean(),
	}

	// Process file status
	for file, fileStatus := range status {
		switch fileStatus.Staging {
		case git.Added, git.Copied:
			gitStatus.Added = append(gitStatus.Added, file)
		case git.Modified:
			gitStatus.Modified = append(gitStatus.Modified, file)
		case git.Deleted:
			gitStatus.Deleted = append(gitStatus.Deleted, file)
		case git.Untracked:
			gitStatus.Untracked = append(gitStatus.Untracked, file)
		}
	}

	return gitStatus, nil
}

// IsClean checks if the repository working tree is clean
func (c *client) IsClean(ctx context.Context, repoPath string) (bool, error) {
	status, err := c.GetStatus(ctx, repoPath)
	if err != nil {
		return false, err
	}
	return status.IsClean, nil
}

// FindMainBranch finds the main branch of a repository (main, master, etc.)
func (c *client) FindMainBranch(ctx context.Context, repoPath string) (string, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if !filepath.IsAbs(repoPath) {
		return "", errors.NewError(errors.ErrInvalidInput, "repository path must be absolute")
	}

	// Ensure we have a timeout context
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
	} else if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 15*time.Second)
		defer cancel()
	}

	// Common main branch names to check in order of preference
	mainBranches := []string{"main", "master", "develop", "dev"}

	// First, try to get the default branch from remote
	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "symbolic-ref", "refs/remotes/origin/HEAD")
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	cmd.Stdin = nil

	if output, err := cmd.Output(); err == nil {
		// Parse output like "refs/remotes/origin/main"
		parts := strings.Split(strings.TrimSpace(string(output)), "/")
		if len(parts) > 0 {
			remoteBranch := parts[len(parts)-1]
			if remoteBranch != "" {
				return remoteBranch, nil
			}
		}
	}

	// If that fails, check which of the common branches exist
	for _, branch := range mainBranches {
		cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "show-ref", "--verify", "--quiet", "refs/heads/"+branch)
		cmd.Env = append(os.Environ(),
			"GIT_TERMINAL_PROMPT=0",
			"GIT_ASKPASS=true",
			"SSH_ASKPASS=true",
		)
		cmd.Stdin = nil

		if err := cmd.Run(); err == nil {
			return branch, nil
		}
	}

	// As a last resort, get the current branch
	cmd = exec.CommandContext(ctx, "git", "-C", repoPath, "branch", "--show-current")
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	cmd.Stdin = nil

	if output, err := cmd.Output(); err == nil {
		currentBranch := strings.TrimSpace(string(output))
		if currentBranch != "" {
			return currentBranch, nil
		}
	}

	// If all else fails, return the default from config or "main"
	return "main", nil
}

// CreateEmptyCommit creates an empty commit with the given message
func (c *client) CreateEmptyCommit(ctx context.Context, repoPath, message string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !filepath.IsAbs(repoPath) {
		return errors.NewError(errors.ErrInvalidInput, "repository path must be absolute")
	}

	// Ensure we have a timeout context
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
	} else if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 15*time.Second)
		defer cancel()
	}

	cmd := exec.CommandContext(ctx, "git", "-C", repoPath, "commit", "--allow-empty", "-m", message)

	// Set environment to prevent interactive prompts
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=true",
		"SSH_ASKPASS=true",
	)
	cmd.Stdin = nil // Prevent waiting for stdin input

	output, err := cmd.CombinedOutput()
	if err != nil {
		return errors.NewGitError(fmt.Sprintf("failed to create empty commit: %s", string(output)), err)
	}

	return nil
}
