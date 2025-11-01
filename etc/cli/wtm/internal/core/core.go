package core

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Color constants for terminal output
const (
	ColorReset  = "\033[0m"
	ColorRed    = "\033[31m"
	ColorGreen  = "\033[32m"
	ColorYellow = "\033[33m"
	ColorBlue   = "\033[34m"
	ColorPurple = "\033[35m"
	ColorCyan   = "\033[36m"
	ColorWhite  = "\033[37m"
)

// PrintColor prints a colored message to stdout
func PrintColor(color, message string) {
	fmt.Printf("%s%s%s\n", color, message, ColorReset)
}

// PrintColorf prints a formatted colored message to stdout
func PrintColorf(color, format string, args ...interface{}) {
	fmt.Printf("%s%s%s\n", color, fmt.Sprintf(format, args...), ColorReset)
}

// CheckTool checks if a command-line tool is available
func CheckTool(tool string) bool {
	_, err := exec.LookPath(tool)
	return err == nil
}

// SelectWithFuzzyFinder uses external fzf to select from a list of options
func SelectWithFuzzyFinder(prompt string, options []string) (string, error) {
	if len(options) == 0 {
		return "", fmt.Errorf("no options provided")
	}

	// Check if fzf is available
	if !CheckTool("fzf") {
		// Fallback to manual selection
		return PromptForChoice(prompt, options)
	}

	return selectWithExternalFzf(options, options, prompt)
}

// DetectPackageManager detects the package manager in a directory
func DetectPackageManager(dir string) string {
	if _, err := os.Stat(filepath.Join(dir, "pnpm-lock.yaml")); err == nil {
		return "pnpm"
	}
	if _, err := os.Stat(filepath.Join(dir, "package-lock.json")); err == nil {
		return "npm"
	}
	if _, err := os.Stat(filepath.Join(dir, "yarn.lock")); err == nil {
		return "yarn"
	}
	return ""
}

// GetFolderNameFromBranch removes prefix from branch name
func GetFolderNameFromBranch(branchName string) (string, error) {
	if branchName == "" {
		return "", fmt.Errorf("branch name is required")
	}

	// Remove prefix (everything before and including the first slash)
	re := regexp.MustCompile(`^[^/]+/(.+)$`)
	matches := re.FindStringSubmatch(branchName)
	if len(matches) > 1 {
		return matches[1], nil
	}
	return branchName, nil
}

// FindMainBranch finds the main branch (prefer develop, fallback to main/master)
func FindMainBranch(repoDir string) (string, error) {
	if repoDir == "" || !isDirectory(repoDir) {
		return "", fmt.Errorf("invalid repository directory")
	}

	branches := []string{"develop", "main", "master"}
	for _, branch := range branches {
		cmd := exec.Command("git", "-C", repoDir, "rev-parse", "--verify", branch)
		if err := cmd.Run(); err == nil {
			return branch, nil
		}
	}

	return "", fmt.Errorf("no main branch (develop/main/master) found")
}

// IsValidBranchName validates a git branch name
func IsValidBranchName(branchName string) bool {
	if branchName == "" {
		return false
	}

	// Check for spaces
	if strings.Contains(branchName, " ") {
		return false
	}

	// Check for git-invalid characters
	invalidChars := regexp.MustCompile(`[\~\^\:\?\*\[\]]`)
	return !invalidChars.MatchString(branchName)
}

// SelectRepository allows interactive selection of a git repository
func SelectRepository(programmingDir string) (string, error) {
	if !isDirectory(programmingDir) {
		return "", fmt.Errorf("programming directory not found: %s", programmingDir)
	}

	repos, err := findGitRepositories(programmingDir)
	if err != nil {
		return "", err
	}

	if len(repos) == 0 {
		return "", fmt.Errorf("no git repositories found in %s", programmingDir)
	}

	PrintColorf(ColorCyan, "Found %d git repositories:", len(repos))

	// Extract just the repository names for selection
	repoNames := make([]string, len(repos))
	for i, repo := range repos {
		repoNames[i] = filepath.Base(repo)
	}

	if CheckTool("fzf") {
		// Use external fzf if available (for better UX)
		return selectWithExternalFzf(repoNames, repos, "Select repository: ")
	}

	// Fallback to fuzzy finder
	selectedName, err := SelectWithFuzzyFinder("Select repository:", repoNames)
	if err != nil {
		return "", fmt.Errorf("repository selection failed: %w", err)
	}

	// Find the full path for the selected repository
	for _, repo := range repos {
		if filepath.Base(repo) == selectedName {
			return repo, nil
		}
	}

	return "", fmt.Errorf("selected repository not found")
}

// FindRepositoryByName finds a repository by name in the programming directory
func FindRepositoryByName(repoName, programmingDir string) (string, error) {
	if repoName == "" {
		return "", fmt.Errorf("repository name is required")
	}

	if !isDirectory(programmingDir) {
		return "", fmt.Errorf("programming directory not found: %s", programmingDir)
	}

	repos, err := findGitRepositories(programmingDir)
	if err != nil {
		return "", err
	}

	// Look for exact repository name match
	for _, repo := range repos {
		if filepath.Base(repo) == repoName {
			return repo, nil
		}
	}

	PrintColorf(ColorRed, "Repository '%s' not found in %s", repoName, programmingDir)
	PrintColor(ColorYellow, "Available repositories:")
	for _, repo := range repos {
		PrintColorf(ColorYellow, "  - %s", filepath.Base(repo))
	}

	return "", fmt.Errorf("repository '%s' not found", repoName)
}

// GetRepository gets a repository either by name or interactive selection
func GetRepository(repoName, programmingDir string) (string, error) {
	if repoName != "" {
		return FindRepositoryByName(repoName, programmingDir)
	}
	return SelectRepository(programmingDir)
}

// InstallDependencies installs dependencies if package manager detected
func InstallDependencies(worktreePath string) error {
	if worktreePath == "" || !isDirectory(worktreePath) {
		return fmt.Errorf("invalid worktree path")
	}

	pm := DetectPackageManager(worktreePath)
	if pm == "" {
		PrintColor(ColorYellow, "No supported lockfile found. Skipping dependency installation.")
		return nil
	}

	PrintColorf(ColorCyan, "Running %s install...", pm)

	var cmd *exec.Cmd
	switch pm {
	case "pnpm":
		if CheckTool("pnpm") {
			cmd = exec.Command("pnpm", "install")
		} else {
			PrintColor(ColorYellow, "pnpm not found, falling back to npm")
			cmd = exec.Command("npm", "install")
		}
	case "yarn":
		if CheckTool("yarn") {
			cmd = exec.Command("yarn", "install")
		} else {
			PrintColor(ColorYellow, "yarn not found, falling back to npm")
			cmd = exec.Command("npm", "install")
		}
	default:
		cmd = exec.Command("npm", "install")
	}

	cmd.Dir = worktreePath
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		PrintColorf(ColorYellow, "Warning: %s install failed", pm)
		return err
	}

	return nil
}

// Helper functions

func isDirectory(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func findGitRepositories(programmingDir string) ([]string, error) {
	var repos []string

	err := filepath.Walk(programmingDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // Skip directories we can't access
		}

		// Only go 2 levels deep to avoid scanning too deeply
		if strings.Count(strings.TrimPrefix(path, programmingDir), string(os.PathSeparator)) > 2 {
			return filepath.SkipDir
		}

		if info.IsDir() && info.Name() == ".git" {
			repoPath := filepath.Dir(path)
			repos = append(repos, repoPath)
			return filepath.SkipDir
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	sort.Strings(repos)
	return repos, nil
}

func selectWithExternalFzf(repoNames, repos []string, prompt string) (string, error) {
	// Create a temporary file with repository names
	tmpFile, err := os.CreateTemp("", "wtm-repos-*.txt")
	if err != nil {
		return "", err
	}
	defer os.Remove(tmpFile.Name())

	for _, name := range repoNames {
		fmt.Fprintln(tmpFile, name)
	}
	tmpFile.Close()

	// Use fzf to select
	cmd := exec.Command("fzf", "--prompt="+prompt, "--height=40%", "--reverse")
	cmd.Stdin, err = os.Open(tmpFile.Name())
	if err != nil {
		return "", err
	}

	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	selectedName := strings.TrimSpace(string(output))
	if selectedName == "" {
		return "", fmt.Errorf("no repository selected")
	}

	// Find the full path for the selected repository
	for _, repo := range repos {
		if filepath.Base(repo) == selectedName {
			return repo, nil
		}
	}

	return "", fmt.Errorf("selected repository not found")
}

// PromptForInput prompts user for input with a message
func PromptForInput(prompt string) (string, error) {
	fmt.Print(prompt)
	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(input), nil
}

// PromptForChoice prompts user to select from numbered options
func PromptForChoice(prompt string, options []string) (string, error) {
	fmt.Println(prompt)
	for i, option := range options {
		fmt.Printf("%d. %s\n", i+1, option)
	}

	input, err := PromptForInput(fmt.Sprintf("Enter number (1-%d): ", len(options)))
	if err != nil {
		return "", err
	}

	choice, err := strconv.Atoi(input)
	if err != nil || choice < 1 || choice > len(options) {
		return "", fmt.Errorf("invalid selection")
	}

	return options[choice-1], nil
}
