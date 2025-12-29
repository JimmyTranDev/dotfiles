package errors

import (
	"fmt"
)

// ErrorCode represents different types of CLI errors
type ErrorCode int

const (
	// General errors
	ErrUnknown ErrorCode = iota
	ErrInvalidInput
	ErrFileNotFound
	ErrPermissionDenied

	// Git errors
	ErrGitOperation
	ErrWorktreeExists
	ErrWorktreeNotFound
	ErrInvalidRepository

	// Configuration errors
	ErrConfigNotFound
	ErrConfigInvalid
)

// CLIError represents a CLI error with context
type CLIError struct {
	Code    ErrorCode
	Message string
	Cause   error
	Context map[string]interface{}
}

func (e *CLIError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("[%d] %s: %v", e.Code, e.Message, e.Cause)
	}
	return fmt.Sprintf("[%d] %s", e.Code, e.Message)
}

func (e *CLIError) Unwrap() error {
	return e.Cause
}

func (e *CLIError) WithContext(key string, value interface{}) *CLIError {
	if e.Context == nil {
		e.Context = make(map[string]interface{})
	}
	e.Context[key] = value
	return e
}

// Error constructors
func NewError(code ErrorCode, message string) *CLIError {
	return &CLIError{
		Code:    code,
		Message: message,
	}
}

func WrapError(code ErrorCode, message string, cause error) *CLIError {
	return &CLIError{
		Code:    code,
		Message: message,
		Cause:   cause,
	}
}

// Git-specific errors
func NewGitError(message string, cause error) *CLIError {
	return WrapError(ErrGitOperation, message, cause)
}

func NewWorktreeExistsError(path string) *CLIError {
	return NewError(ErrWorktreeExists, fmt.Sprintf("worktree already exists at %s", path))
}

func NewWorktreeNotFoundError(path string) *CLIError {
	return NewError(ErrWorktreeNotFound, fmt.Sprintf("worktree not found at %s", path))
}

// Configuration errors
func NewConfigError(message string, cause error) *CLIError {
	return WrapError(ErrConfigInvalid, message, cause)
}
