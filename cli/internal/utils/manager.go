package utils

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/jimmy/dotfiles-cli/internal/config"
)

// Manager handles utility operations
type Manager interface {
	KillPort(port int) error
	SortCSV(filePath string, interactive bool) error
}

// manager implements the Manager interface
type manager struct {
	config *config.Config
}

// NewManager creates a new utilities manager
func NewManager(cfg *config.Config) Manager {
	return &manager{
		config: cfg,
	}
}

// KillPort kills processes running on the specified port
func (m *manager) KillPort(port int) error {
	// Use lsof to find processes on the port
	cmd := exec.Command("lsof", "-ti", fmt.Sprintf("tcp:%d", port))
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out

	if err := cmd.Run(); err != nil {
		// lsof returns exit code 1 if no processes found
		if exitError, ok := err.(*exec.ExitError); ok && exitError.ExitCode() == 1 {
			return fmt.Errorf("no process found on port %d", port)
		}
		return fmt.Errorf("failed to check port %d: %w", port, err)
	}

	pidsStr := strings.TrimSpace(out.String())
	if pidsStr == "" {
		return fmt.Errorf("no process found on port %d", port)
	}

	// Parse PIDs and kill each process
	pids := strings.Split(pidsStr, "\n")
	for _, pidStr := range pids {
		pidStr = strings.TrimSpace(pidStr)
		if pidStr == "" {
			continue
		}

		pid, err := strconv.Atoi(pidStr)
		if err != nil {
			continue // Skip invalid PIDs
		}

		// Kill the process
		killCmd := exec.Command("kill", "-9", strconv.Itoa(pid))
		if err := killCmd.Run(); err != nil {
			return fmt.Errorf("failed to kill process %d: %w", pid, err)
		}
	}

	return nil
}

// SortCSV sorts CSV files by commonness score
func (m *manager) SortCSV(filePath string, interactive bool) error {
	if interactive {
		// Find CSV files in known directories
		csvFiles, err := m.findCSVFiles()
		if err != nil {
			return fmt.Errorf("failed to find CSV files: %w", err)
		}

		if len(csvFiles) == 0 {
			return fmt.Errorf("no CSV files found in ranked words directories")
		}

		// Use FZF for selection
		selected, err := m.selectCSVWithFZF(csvFiles)
		if err != nil {
			// Fallback to numbered selection
			selected, err = m.selectCSVWithNumbers(csvFiles)
			if err != nil {
				return err
			}
		}

		filePath = selected
	}

	// Verify file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return fmt.Errorf("file does not exist: %s", filePath)
	}

	// Sort the CSV file
	return m.sortCSVByCommonnessScore(filePath)
}

// findCSVFiles searches for CSV files in known directories
func (m *manager) findCSVFiles() ([]string, error) {
	searchDirs := []string{
		fmt.Sprintf("%s/Programming/massvocabulary/old2/3/2_ranked_words", m.config.Directories.Home),
		fmt.Sprintf("%s/Programming/massvocabulary/old2/3/3_sorted_words", m.config.Directories.Home),
		fmt.Sprintf("%s/Programming/massvocabulary/massvocabulary-cli-old/src/data/2_ranked_words", m.config.Directories.Home),
	}

	var csvFiles []string

	for _, dir := range searchDirs {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}

		// Find CSV files in this directory
		cmd := exec.Command("find", dir, "-name", "*.csv", "-type", "f")
		output, err := cmd.Output()
		if err != nil {
			continue
		}

		files := strings.Split(strings.TrimSpace(string(output)), "\n")
		for _, file := range files {
			if file != "" {
				csvFiles = append(csvFiles, file)
			}
		}
	}

	return csvFiles, nil
}

// selectCSVWithFZF uses FZF for interactive CSV file selection
func (m *manager) selectCSVWithFZF(files []string) (string, error) {
	// Check if fzf is available
	if _, err := exec.LookPath("fzf"); err != nil {
		return "", fmt.Errorf("fzf not found: %w", err)
	}

	// Prepare file list for FZF
	input := strings.Join(files, "\n")

	// Run FZF
	cmd := exec.Command("fzf", "--prompt=Select CSV file: ", "--height=80%", "--reverse",
		"--preview=echo 'File: {}'; echo; head -10 {}", "--preview-window=right:50%")
	cmd.Stdin = strings.NewReader(input)

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("fzf selection cancelled or failed: %w", err)
	}

	selected := strings.TrimSpace(output.String())
	if selected == "" {
		return "", fmt.Errorf("no file selected")
	}

	return selected, nil
}

// selectCSVWithNumbers provides fallback numbered selection
func (m *manager) selectCSVWithNumbers(files []string) (string, error) {
	fmt.Println("\nAvailable CSV files:")
	for i, file := range files {
		basename := file[strings.LastIndex(file, "/")+1:]
		dirname := strings.Replace(file[:strings.LastIndex(file, "/")], m.config.Directories.Home, "~", 1)
		fmt.Printf("%d. %s (in %s)\n", i+1, basename, dirname)
	}

	fmt.Printf("Enter number (1-%d): ", len(files))

	scanner := bufio.NewScanner(os.Stdin)
	if !scanner.Scan() {
		return "", fmt.Errorf("failed to read input")
	}

	input := strings.TrimSpace(scanner.Text())
	selection, err := strconv.Atoi(input)
	if err != nil {
		return "", fmt.Errorf("invalid number: %s", input)
	}

	if selection < 1 || selection > len(files) {
		return "", fmt.Errorf("selection out of range: %d (valid: 1-%d)", selection, len(files))
	}

	return files[selection-1], nil
}

// sortCSVByCommonnessScore sorts a CSV file by commonness score column
func (m *manager) sortCSVByCommonnessScore(filePath string) error {
	// Create backup
	backupPath := filePath + ".backup"
	if err := m.copyFile(filePath, backupPath); err != nil {
		return fmt.Errorf("failed to create backup: %w", err)
	}

	// Read and sort the CSV
	// This is a simplified implementation - the original shell script is quite complex
	// For now, we'll use a basic sort command
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`
		{
			head -n1 "%s"
			tail -n+2 "%s" | sort -t',' -k2,2nr
		} > "%s.tmp" && mv "%s.tmp" "%s"
	`, filePath, filePath, filePath, filePath, filePath))

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to sort CSV file: %w", err)
	}

	return nil
}

// copyFile copies a file from src to dst
func (m *manager) copyFile(src, dst string) error {
	cmd := exec.Command("cp", src, dst)
	return cmd.Run()
}
