package ui

import (
	"time"

	"github.com/briandowns/spinner"
	"github.com/fatih/color"
)

// SpinnerConfig holds configuration for a spinner
type SpinnerConfig struct {
	Message string
	Color   string
}

// NewSpinner creates and returns a new spinner with the given configuration
func NewSpinner(config SpinnerConfig) *spinner.Spinner {
	s := spinner.New(spinner.CharSets[14], 100*time.Millisecond)

	// Set color based on config
	switch config.Color {
	case "blue":
		s.Color("blue")
	case "green":
		s.Color("green")
	case "yellow":
		s.Color("yellow")
	case "cyan":
		s.Color("cyan")
	default:
		s.Color("cyan") // Default color
	}

	if config.Message != "" {
		s.Suffix = " " + config.Message
	}

	return s
}

// WithSpinner runs a function with a spinner and handles success/error states
func WithSpinner(config SpinnerConfig, fn func() error) error {
	s := NewSpinner(config)
	s.Start()
	defer s.Stop()

	err := fn()

	if err != nil {
		s.FinalMSG = color.RedString("✗ %s failed\n", config.Message)
	} else {
		s.FinalMSG = color.GreenString("✓ %s completed\n", config.Message)
	}

	return err
}

// WithSpinnerResult runs a function with a spinner and returns both result and error
func WithSpinnerResult[T any](config SpinnerConfig, fn func() (T, error)) (T, error) {
	var result T
	s := NewSpinner(config)
	s.Start()
	defer s.Stop()

	result, err := fn()

	if err != nil {
		s.FinalMSG = color.RedString("✗ %s failed\n", config.Message)
	} else {
		s.FinalMSG = "" // No final message for successful operations that return data
	}

	return result, err
}
