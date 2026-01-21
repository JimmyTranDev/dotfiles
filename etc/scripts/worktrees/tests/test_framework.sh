#!/bin/zsh
# ===================================================================
# test_framework.sh - Simple Test Framework for Worktree Scripts
# ===================================================================

# Test framework colors and counters
TEST_PASSED=0
TEST_FAILED=0
TEST_TOTAL=0

# Test framework functions
print_test_header() {
  echo
  print -P "%F{cyan}========================================%f"
  print -P "%F{cyan}$1%f"
  print -P "%F{cyan}========================================%f"
}

print_test_result() {
  local test_name="$1"
  local test_status="$2"
  local message="$3"
  
  ((TEST_TOTAL++))
  
  if [[ "$test_status" == "PASS" ]]; then
    ((TEST_PASSED++))
    print -P "%F{green}✅ PASS%f: $test_name"
    [[ -n "$message" ]] && print -P "   %F{green}$message%f"
  else
    ((TEST_FAILED++))
    print -P "%F{red}❌ FAIL%f: $test_name"
    [[ -n "$message" ]] && print -P "   %F{red}$message%f"
  fi
}

print_test_summary() {
  echo
  print -P "%F{cyan}========================================%f"
  print -P "%F{cyan}TEST SUMMARY%f"
  print -P "%F{cyan}========================================%f"
  print -P "Total Tests: $TEST_TOTAL"
  print -P "%F{green}Passed: $TEST_PASSED%f"
  print -P "%F{red}Failed: $TEST_FAILED%f"
  
  if [[ $TEST_FAILED -eq 0 ]]; then
    print -P "%F{green}🎉 All tests passed!%f"
    return 0
  else
    print -P "%F{red}💥 Some tests failed!%f"
    return 1
  fi
}

# Test assertion functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"
  
  if [[ "$expected" == "$actual" ]]; then
    print_test_result "$test_name" "PASS" "Expected: '$expected', Got: '$actual'"
  else
    print_test_result "$test_name" "FAIL" "Expected: '$expected', Got: '$actual'"
  fi
}

assert_not_equals() {
  local not_expected="$1"
  local actual="$2"
  local test_name="$3"
  
  if [[ "$not_expected" != "$actual" ]]; then
    print_test_result "$test_name" "PASS" "Not expected: '$not_expected', Got: '$actual'"
  else
    print_test_result "$test_name" "FAIL" "Should not equal: '$not_expected', but got: '$actual'"
  fi
}

assert_command_success() {
  local command="$1"
  local test_name="$2"
  
  if eval "$command" >/dev/null 2>&1; then
    print_test_result "$test_name" "PASS" "Command succeeded: $command"
  else
    print_test_result "$test_name" "FAIL" "Command failed: $command"
  fi
}

assert_command_failure() {
  local command="$1"
  local test_name="$2"
  
  if ! eval "$command" >/dev/null 2>&1; then
    print_test_result "$test_name" "PASS" "Command failed as expected: $command"
  else
    print_test_result "$test_name" "FAIL" "Command should have failed: $command"
  fi
}

assert_file_exists() {
  local file_path="$1"
  local test_name="$2"
  
  if [[ -f "$file_path" ]]; then
    print_test_result "$test_name" "PASS" "File exists: $file_path"
  else
    print_test_result "$test_name" "FAIL" "File does not exist: $file_path"
  fi
}

assert_directory_exists() {
  local dir_path="$1"
  local test_name="$2"
  
  if [[ -d "$dir_path" ]]; then
    print_test_result "$test_name" "PASS" "Directory exists: $dir_path"
  else
    print_test_result "$test_name" "FAIL" "Directory does not exist: $dir_path"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local test_name="$3"
  
  if [[ "$haystack" == *"$needle"* ]]; then
    print_test_result "$test_name" "PASS" "String contains expected text"
  else
    print_test_result "$test_name" "FAIL" "String '$haystack' does not contain '$needle'"
  fi
}

# Setup test environment
setup_test_env() {
  export TEST_WORKTREES_DIR="/tmp/worktree_tests_$$"
  export WORKTREES_DIR="$TEST_WORKTREES_DIR"
  export TEST_REPO_DIR="/tmp/test_repo_$$"
  
  # Clean up any existing test directories
  rm -rf "$TEST_WORKTREES_DIR" "$TEST_REPO_DIR" 2>/dev/null
  
  # Create test directories
  mkdir -p "$TEST_WORKTREES_DIR"
  mkdir -p "$TEST_REPO_DIR"
  
  # Initialize a test git repository
  cd "$TEST_REPO_DIR"
  git init >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  echo "# Test Repository" > README.md
  git add README.md >/dev/null 2>&1
  git commit -m "Initial commit" >/dev/null 2>&1
  git branch -M main >/dev/null 2>&1
}

# Cleanup test environment
cleanup_test_env() {
  rm -rf "$TEST_WORKTREES_DIR" "$TEST_REPO_DIR" 2>/dev/null
}

# Mock functions for testing
mock_fzf() {
  # Mock fzf to return the first option
  head -n1
}

mock_jira() {
  # Mock jira CLI for testing
  case "$1" in
    "issue")
      case "$2" in
        "view")
          echo "Summary: Test JIRA ticket summary"
          ;;
      esac
      ;;
  esac
}
