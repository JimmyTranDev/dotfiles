package git

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestDeleteWorktree_TimeoutHandling(t *testing.T) {
	client := NewClient()

	tests := []struct {
		name         string
		worktreePath string
		timeout      time.Duration
		expectError  bool
		errorType    string
	}{
		{
			name:         "invalid empty path",
			worktreePath: "",
			timeout:      5 * time.Second,
			expectError:  true,
			errorType:    "invalid worktree path",
		},
		{
			name:         "invalid root path",
			worktreePath: "/",
			timeout:      5 * time.Second,
			expectError:  true,
			errorType:    "invalid worktree path",
		},
		{
			name:         "invalid relative path",
			worktreePath: "relative/path",
			timeout:      5 * time.Second,
			expectError:  true,
			errorType:    "worktree path must be absolute",
		},
		{
			name:         "nonexistent worktree with proper timeout",
			worktreePath: "/tmp/nonexistent-worktree-test",
			timeout:      10 * time.Second,
			expectError:  false, // Actually, this should succeed with fallback since directory doesn't exist
			errorType:    "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), tt.timeout)
			defer cancel()

			result, err := client.DeleteWorktree(ctx, tt.worktreePath)

			if tt.expectError {
				if err == nil {
					t.Errorf("expected error but got none")
					return
				}
				// Verify that the error contains expected type/message
				if tt.errorType != "" && !containsIgnoreCase(err.Error(), tt.errorType) {
					t.Errorf("expected error to contain '%s', got: %v", tt.errorType, err)
				}
				// Most importantly: verify that the operation completed within timeout
				select {
				case <-ctx.Done():
					if ctx.Err() == context.DeadlineExceeded {
						t.Errorf("operation timed out - this indicates the infinite loading bug is not fixed")
					}
				default:
					// Good: operation completed before timeout
				}
			} else {
				if err != nil {
					t.Errorf("expected no error but got: %v", err)
				}
				if result == nil {
					t.Errorf("expected result but got nil")
				}
			}
		})
	}
}

func TestDeleteWorktree_RepositoryDiscoveryLoop(t *testing.T) {
	client := NewClient()

	// Create a temporary directory structure that could potentially cause infinite loops
	tmpDir, err := os.MkdirTemp("", "worktree-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create a deep directory structure
	deepPath := filepath.Join(tmpDir, "level1", "level2", "level3", "level4", "level5", "fake-worktree")
	if err := os.MkdirAll(deepPath, 0755); err != nil {
		t.Fatalf("failed to create deep path: %v", err)
	}

	// Test that the repository discovery doesn't hang even with deep paths
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	result, err := client.DeleteWorktree(ctx, deepPath)

	// We expect this to succeed with fallback (since directory doesn't exist, it can be "cleaned up")
	select {
	case <-ctx.Done():
		if ctx.Err() == context.DeadlineExceeded {
			t.Errorf("repository discovery loop took too long - infinite loop bug not fixed")
		}
	default:
		// Good: operation completed within reasonable time
		if err != nil {
			t.Logf("Got error (this might be expected): %v", err)
		}
		if result != nil {
			t.Logf("Got result - used fallback: %v, method: %s", result.UsedFallback, result.Method)
		}
	}
}

func TestDeleteWorktree_ContextCancellation(t *testing.T) {
	client := NewClient()

	// Test that context cancellation is properly handled
	ctx, cancel := context.WithCancel(context.Background())

	// Cancel the context immediately
	cancel()

	fakePath := "/tmp/fake-worktree-for-cancellation-test"

	_, err := client.DeleteWorktree(ctx, fakePath)

	// The operation should recognize context cancellation quickly
	if err == nil {
		t.Errorf("expected error due to cancelled context, but got none")
	}
}

func containsIgnoreCase(s, substr string) bool {
	return strings.Contains(strings.ToLower(s), strings.ToLower(substr))
}
