#!/bin/zsh
# ===================================================================
# run_tests.sh - Test Runner for Worktree Management System
# ===================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Test files to run
TEST_FILES=(
  "$SCRIPT_DIR/test_core.sh"
  "$SCRIPT_DIR/test_jira.sh" 
  "$SCRIPT_DIR/test_commands.sh"
  "$SCRIPT_DIR/test_integration.sh"
)

# Colors for output
print_header() {
  echo
  print -P "%F{magenta}╔══════════════════════════════════════════════════════════════════╗%f"
  print -P "%F{magenta}║%f %F{white}%-64s%f %F{magenta}║%f" "$1"
  print -P "%F{magenta}╚══════════════════════════════════════════════════════════════════╝%f"
  echo
}

print_separator() {
  print -P "%F{cyan}════════════════════════════════════════════════════════════════════%f"
}

# Track overall test results
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_TEST_FILES=()

run_single_test() {
  local test_file="$1"
  local test_name=$(basename "$test_file" .sh)
  
  print_header "Running $test_name"
  
  if [[ ! -f "$test_file" ]]; then
    print -P "%F{red}❌ Test file not found: $test_file%f"
    return 1
  fi
  
  if [[ ! -x "$test_file" ]]; then
    chmod +x "$test_file"
  fi
  
  # Run the test and capture output
  local test_output
  local test_exit_code
  
  test_output=$("$test_file" 2>&1)
  test_exit_code=$?
  
  # Display the output
  echo "$test_output"
  
  # Extract test counts from output
  local passed=$(echo "$test_output" | grep "Passed:" | grep -o '[0-9]\+' | tail -1)
  local failed=$(echo "$test_output" | grep "Failed:" | grep -o '[0-9]\+' | tail -1)
  local total=$(echo "$test_output" | grep "Total Tests:" | grep -o '[0-9]\+' | tail -1)
  
  # Update overall counts
  if [[ -n "$total" && "$total" =~ ^[0-9]+$ ]]; then
    ((TOTAL_TESTS += total))
  fi
  if [[ -n "$passed" && "$passed" =~ ^[0-9]+$ ]]; then
    ((TOTAL_PASSED += passed))
  fi
  if [[ -n "$failed" && "$failed" =~ ^[0-9]+$ ]]; then
    ((TOTAL_FAILED += failed))
  fi
  
  # Track failed test files
  if [[ $test_exit_code -ne 0 ]] || [[ -n "$failed" && "$failed" -gt 0 ]]; then
    FAILED_TEST_FILES+=("$test_name")
  fi
  
  print_separator
  
  return $test_exit_code
}

run_all_tests() {
  print_header "Worktree Management System Test Suite"
  
  print -P "%F{cyan}Running comprehensive tests for the modular worktree system...%f"
  echo
  
  # Run each test file
  for test_file in "${TEST_FILES[@]}"; do
    run_single_test "$test_file"
    echo
  done
}

print_final_summary() {
  print_header "FINAL TEST SUMMARY"
  
  print -P "Total Test Files: %F{cyan}${#TEST_FILES[@]}%f"
  print -P "Total Tests: %F{cyan}$TOTAL_TESTS%f"
  print -P "Total Passed: %F{green}$TOTAL_PASSED%f"
  print -P "Total Failed: %F{red}$TOTAL_FAILED%f"
  
  echo
  
  if [[ $TOTAL_FAILED -eq 0 ]]; then
    print -P "%F{green}🎉 ALL TESTS PASSED! 🎉%f"
    print -P "%F{green}The worktree management system is working correctly!%f"
    echo
    return 0
  else
    print -P "%F{red}💥 SOME TESTS FAILED 💥%f"
    
    if [[ ${#FAILED_TEST_FILES[@]} -gt 0 ]]; then
      echo
      print -P "%F{yellow}Failed test files:%f"
      for failed_file in "${FAILED_TEST_FILES[@]}"; do
        print -P "  %F{red}• $failed_file%f"
      done
    fi
    
    echo
    print -P "%F{yellow}Please review the test output above and fix any issues.%f"
    echo
    return 1
  fi
}

show_help() {
  cat << 'EOF'
Worktree Test Runner

USAGE:
  ./run_tests.sh [options] [specific_test]

OPTIONS:
  -h, --help          Show this help message
  -l, --list          List available tests
  -v, --verbose       Run tests with verbose output

SPECIFIC TESTS:
  core               Run only core function tests
  jira               Run only JIRA integration tests  
  commands           Run only command function tests
  integration        Run only integration tests

EXAMPLES:
  ./run_tests.sh                 # Run all tests
  ./run_tests.sh core           # Run only core tests
  ./run_tests.sh --list         # List available tests
  ./run_tests.sh --verbose     # Run with verbose output

EOF
}

list_tests() {
  print_header "Available Tests"
  
  for test_file in "${TEST_FILES[@]}"; do
    local test_name=$(basename "$test_file" .sh)
    local description=""
    
    case "$test_name" in
      "test_core")
        description="Core utility functions (print_color, check_tool, etc.)"
        ;;
      "test_jira")
        description="JIRA integration and pattern matching"
        ;;
      "test_commands")
        description="Worktree command functions (create, delete, etc.)"
        ;;
      "test_integration")
        description="Main script and integration testing"
        ;;
    esac
    
    print -P "%F{cyan}$test_name%f: $description"
  done
  echo
}

# Main function
main() {
  local run_specific=""
  local verbose=false
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        return 0
        ;;
      -l|--list)
        list_tests
        return 0
        ;;
      -v|--verbose)
        verbose=true
        shift
        ;;
      core|jira|commands|integration)
        run_specific="test_$1.sh"
        shift
        ;;
      *)
        print -P "%F{red}Unknown option: $1%f"
        show_help
        return 1
        ;;
    esac
  done
  
  # Make all test files executable
  chmod +x "$SCRIPT_DIR"/test_*.sh
  
  if [[ -n "$run_specific" ]]; then
    # Run specific test
    local specific_test="$SCRIPT_DIR/$run_specific"
    if [[ -f "$specific_test" ]]; then
      run_single_test "$specific_test"
      print_final_summary
    else
      print -P "%F{red}Test file not found: $run_specific%f"
      return 1
    fi
  else
    # Run all tests
    run_all_tests
    print_final_summary
  fi
}

# Run main function with all arguments
main "$@"
