#!/bin/zsh
# ===================================================================
# test_core.sh - Tests for Core Utility Functions
# ===================================================================

# Source the test framework and core modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"
source "$SCRIPT_DIR/../config.sh"
source "$SCRIPT_DIR/../lib/core.sh"

test_core_functions() {
  print_test_header "Testing Core Utility Functions"
  
  # Test print_color function
  local color_output
  color_output=$(print_color red "test message" 2>&1)
  assert_contains "$color_output" "test message" "print_color outputs message"
  
  # Test check_tool function with existing tool
  assert_command_success "check_tool git" "check_tool succeeds for git"
  
  # Test check_tool function with non-existing tool
  assert_command_failure "check_tool nonexistent_tool_12345" "check_tool fails for non-existent tool"
  
  # Test select_fzf function (mock)
  local select_result
  select_result=$(echo -e "option1\noption2\noption3" | mock_fzf)
  assert_equals "option1" "$select_result" "mock select_fzf returns first option"
  
  # Test detect_package_manager function
  setup_test_env
  cd "$TEST_REPO_DIR"
  
  # Test with no package files
  local pm_result
  pm_result=$(detect_package_manager)
  assert_equals "" "$pm_result" "detect_package_manager returns empty for no package files"
  
  # Test with package-lock.json
  touch package-lock.json
  pm_result=$(detect_package_manager)
  assert_equals "npm" "$pm_result" "detect_package_manager detects npm"
  rm package-lock.json
  
  # Test with yarn.lock
  touch yarn.lock
  pm_result=$(detect_package_manager)
  assert_equals "yarn" "$pm_result" "detect_package_manager detects yarn"
  rm yarn.lock
  
  # Test with pnpm-lock.yaml (highest priority)
  touch package-lock.json yarn.lock pnpm-lock.yaml
  pm_result=$(detect_package_manager)
  assert_equals "pnpm" "$pm_result" "detect_package_manager prefers pnpm"
  
  cleanup_test_env
}

test_folder_name_functions() {
  print_test_header "Testing Folder Name Functions"
  
  # Test get_folder_name_from_branch
  local folder_name
  folder_name=$(get_folder_name_from_branch "feature/ABC-123-test-branch")
  assert_equals "ABC-123-test-branch" "$folder_name" "get_folder_name_from_branch removes feature/ prefix"
  
  folder_name=$(get_folder_name_from_branch "ABC-123-test-branch")
  assert_equals "ABC-123-test-branch" "$folder_name" "get_folder_name_from_branch handles branch without prefix"
  
  folder_name=$(get_folder_name_from_branch "bugfix/issue-456")
  assert_equals "issue-456" "$folder_name" "get_folder_name_from_branch removes bugfix/ prefix"
}

test_git_functions() {
  print_test_header "Testing Git Utility Functions"
  
  setup_test_env
  cd "$TEST_REPO_DIR"
  
  # Test find_main_branch
  local main_branch
  main_branch=$(find_main_branch "$TEST_REPO_DIR")
  assert_equals "main" "$main_branch" "find_main_branch detects main branch"
  
  # Test with master branch
  git branch master >/dev/null 2>&1
  git checkout master >/dev/null 2>&1
  git branch -d main >/dev/null 2>&1
  main_branch=$(find_main_branch "$TEST_REPO_DIR")
  assert_equals "master" "$main_branch" "find_main_branch detects master branch"
  
  cleanup_test_env
}

test_repository_selection() {
  print_test_header "Testing Repository Selection Functions"
  
  # Test that select_repository function exists
  if declare -f select_repository >/dev/null; then
    print_test_result "select_repository function exists" "PASS"
  else
    print_test_result "select_repository function exists" "FAIL"
  fi
  
  # Test repository selection in a controlled environment
  setup_test_env
  
  # Create a test programming directory structure
  local test_prog_dir="$TEST_REPO_DIR/test_programming"
  mkdir -p "$test_prog_dir/repo1" "$test_prog_dir/repo2"
  
  # Initialize test repositories
  cd "$test_prog_dir/repo1"
  git init >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  echo "test" > test.txt
  git add test.txt >/dev/null 2>&1
  git commit -m "Initial commit" >/dev/null 2>&1
  
  cd "$test_prog_dir/repo2"
  git init >/dev/null 2>&1
  git config user.email "test@example.com" >/dev/null 2>&1
  git config user.name "Test User" >/dev/null 2>&1
  echo "test2" > test2.txt
  git add test2.txt >/dev/null 2>&1
  git commit -m "Initial commit" >/dev/null 2>&1
  
  # Test with custom PROGRAMMING_DIR
  local old_programming_dir="$PROGRAMMING_DIR"
  export PROGRAMMING_DIR="$test_prog_dir"
  
  # Mock the selection (select first repo)
  local selected_repo
  selected_repo=$(echo "1" | select_repository 2>/dev/null)
  
  if [[ "$selected_repo" == "$test_prog_dir/repo1" ]]; then
    print_test_result "Repository selection returns correct path" "PASS"
  else
    print_test_result "Repository selection returns correct path" "FAIL" "Expected: $test_prog_dir/repo1, Got: $selected_repo"
  fi
  
  # Restore original PROGRAMMING_DIR
  
  cleanup_test_env
}

test_repository_lookup() {
  print_test_header "Testing Repository Lookup Functions"
  
  # Setup test environment with mock repositories
  setup_test_env
  local mock_programming_dir="$TEMP_DIR/programming"
  mkdir -p "$mock_programming_dir"
  mkdir -p "$mock_programming_dir/test-repo"
  mkdir -p "$mock_programming_dir/another-repo"
  mkdir -p "$mock_programming_dir/my-project"
  
  # Test find_repository_by_name with exact match
  local found_repo
  found_repo=$(PROGRAMMING_DIR="$mock_programming_dir" find_repository_by_name "test-repo")
  assert_equals "$mock_programming_dir/test-repo" "$found_repo" "find_repository_by_name finds exact match"
  
  # Test find_repository_by_name with partial match
  found_repo=$(PROGRAMMING_DIR="$mock_programming_dir" find_repository_by_name "test")
  assert_equals "$mock_programming_dir/test-repo" "$found_repo" "find_repository_by_name finds partial match"
  
  # Test find_repository_by_name with non-existent repo
  found_repo=$(PROGRAMMING_DIR="$mock_programming_dir" find_repository_by_name "nonexistent" 2>/dev/null)
  assert_equals "" "$found_repo" "find_repository_by_name returns empty for non-existent repo"
  
  # Test get_repository with valid repo name (mock interactive selection to avoid fzf)
  mock_select_repository() {
    echo "$mock_programming_dir/test-repo"
  }
  
  # Override select_repository function temporarily
  local original_select_repository_function="$(declare -f select_repository)"
  eval "select_repository() { mock_select_repository; }"
  
  # Test get_repository with repo name
  found_repo=$(PROGRAMMING_DIR="$mock_programming_dir" get_repository "test-repo")
  assert_equals "$mock_programming_dir/test-repo" "$found_repo" "get_repository works with valid repo name"
  
  # Test get_repository without repo name (should use interactive selection)
  found_repo=$(PROGRAMMING_DIR="$mock_programming_dir" get_repository "")
  assert_equals "$mock_programming_dir/test-repo" "$found_repo" "get_repository falls back to interactive selection"
  
  # Test get_repository with invalid repo name should show error and still work
  found_repo=$(PROGRAMMING_DIR="$mock_programming_dir" get_repository "invalid-repo" 2>/dev/null)
  assert_equals "$mock_programming_dir/test-repo" "$found_repo" "get_repository handles invalid repo name gracefully"
  
  # Restore original functions
  if [[ -n "$original_select_repository_function" ]]; then
    eval "$original_select_repository_function"
  fi
  
  cleanup_test_env
}

test_validation_functions() {
  print_test_header "Testing Validation Functions"
  
  # Test is_valid_branch_name
  assert_command_success "is_valid_branch_name 'feature/test-branch'" "is_valid_branch_name accepts valid branch name"
  assert_command_success "is_valid_branch_name 'ABC-123'" "is_valid_branch_name accepts JIRA ticket format"
  assert_command_failure "is_valid_branch_name 'invalid branch name'" "is_valid_branch_name rejects spaces"
  assert_command_failure "is_valid_branch_name ''" "is_valid_branch_name rejects empty string"
}

# Run all tests
main() {
  test_core_functions
  test_folder_name_functions
  test_git_functions
  test_repository_selection
  test_repository_lookup
  test_validation_functions
  
  print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "$0" == *"test_core.sh" ]]; then
  main "$@"
fi
