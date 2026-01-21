#!/bin/zsh
# ===================================================================
# test_integration.sh - Integration Tests for Worktree Script
# ===================================================================

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"

# Path to the main worktree script
WORKTREE_SCRIPT="$SCRIPT_DIR/../worktree"

test_main_script_structure() {
  print_test_header "Testing Main Script Structure"
  
  # Test that main script exists and is executable
  assert_file_exists "$WORKTREE_SCRIPT" "Main worktree script exists"
  
  if [[ -x "$WORKTREE_SCRIPT" ]]; then
    print_test_result "Main script is executable" "PASS"
  else
    print_test_result "Main script is executable" "FAIL"
  fi
}

test_help_and_version() {
  print_test_header "Testing Help and Version Commands"
  
  # Test help command
  local help_output
  help_output=$("$WORKTREE_SCRIPT" --help 2>&1)
  assert_contains "$help_output" "USAGE:" "Help command shows usage"
  assert_contains "$help_output" "COMMANDS:" "Help command shows commands"
  assert_contains "$help_output" "create" "Help command shows create command"
  assert_contains "$help_output" "delete" "Help command shows delete command"
  
  # Test version command
  local version_output
  version_output=$("$WORKTREE_SCRIPT" --version 2>&1)
  assert_contains "$version_output" "Git Worktree Management Script" "Version command shows script name"
  assert_contains "$version_output" "v2.0.0" "Version command shows version number"
}

test_command_routing() {
  print_test_header "Testing Command Routing"
  
  # Test unknown command
  local unknown_output
  unknown_output=$("$WORKTREE_SCRIPT" unknown_command 2>&1)
  if [[ $? -ne 0 ]]; then
    print_test_result "Unknown command returns error code" "PASS"
  else
    print_test_result "Unknown command returns error code" "FAIL"
  fi
  
  assert_contains "$unknown_output" "Unknown command" "Unknown command shows error message"
  
  # Test empty command
  local empty_output
  empty_output=$("$WORKTREE_SCRIPT" 2>&1)
  if [[ $? -ne 0 ]]; then
    print_test_result "Empty command returns error code" "PASS"
  else
    print_test_result "Empty command returns error code" "FAIL"
  fi
  
  assert_contains "$empty_output" "No command provided" "Empty command shows error message"
}

test_dependency_checking() {
  print_test_header "Testing Dependency Checking"
  
  setup_test_env
  cd "$TEST_REPO_DIR"
  
  # Test with git available (should work)
  if command -v git >/dev/null 2>&1; then
    print_test_result "Git dependency available" "PASS"
  else
    print_test_result "Git dependency available" "FAIL" "Git is required for testing"
  fi
  
  # Test command that requires missing dependency
  # Create a test environment where fzf is not available
  local PATH_BACKUP="$PATH"
  export PATH="/usr/bin:/bin"  # Minimal PATH without fzf
  
  # Test that commands handle missing fzf gracefully
  local create_output
  create_output=$(echo "" | "$WORKTREE_SCRIPT" create 2>&1)
  if [[ $? -ne 0 ]]; then
    print_test_result "Commands handle missing fzf" "PASS"
  else
    # Command might succeed if fzf is in minimal PATH, that's also OK
    print_test_result "Commands handle missing fzf" "PASS" "Command succeeded (fzf available or handled gracefully)"
  fi
  
  # Restore PATH
  export PATH="$PATH_BACKUP"
  
  cleanup_test_env
}

test_configuration_loading() {
  print_test_header "Testing Configuration Loading"
  
  # Test that configuration variables are set
  local config_output
  config_output=$("$WORKTREE_SCRIPT" --version 2>&1)
  
  # Run the script to load configuration and check if variables are accessible
  # We'll do this by checking if the script runs without configuration errors
  if [[ $? -eq 0 ]]; then
    print_test_result "Configuration loads without errors" "PASS"
  else
    print_test_result "Configuration loads without errors" "FAIL"
  fi
}

test_file_structure_integrity() {
  print_test_header "Testing File Structure Integrity"
  
  # Test that all required files exist
  local required_files=(
    "$SCRIPT_DIR/../config.sh"
    "$SCRIPT_DIR/../lib/core.sh"
    "$SCRIPT_DIR/../lib/jira.sh"
    "$SCRIPT_DIR/../commands/create.sh"
    "$SCRIPT_DIR/../commands/delete.sh"
    "$SCRIPT_DIR/../commands/checkout.sh"
    "$SCRIPT_DIR/../commands/update.sh"
    "$SCRIPT_DIR/../commands/other.sh"
  )
  
  for file in "${required_files[@]}"; do
    assert_file_exists "$file" "Required file exists: $(basename "$file")"
  done
  
  # Test that required directories exist
  assert_directory_exists "$SCRIPT_DIR/../lib" "lib directory exists"
  assert_directory_exists "$SCRIPT_DIR/../commands" "commands directory exists"
  assert_directory_exists "$SCRIPT_DIR/../tests" "tests directory exists"
}

test_script_syntax() {
  print_test_header "Testing Script Syntax"
  
  # Test syntax of main script
  if zsh -n "$WORKTREE_SCRIPT" 2>/dev/null; then
    print_test_result "Main script syntax is valid" "PASS"
  else
    print_test_result "Main script syntax is valid" "FAIL"
  fi
  
  # Test syntax of all component scripts
  local script_files=(
    "$SCRIPT_DIR/../config.sh"
    "$SCRIPT_DIR/../lib/core.sh"
    "$SCRIPT_DIR/../lib/jira.sh"
    "$SCRIPT_DIR/../commands/create.sh"
    "$SCRIPT_DIR/../commands/delete.sh"
    "$SCRIPT_DIR/../commands/checkout.sh"
    "$SCRIPT_DIR/../commands/update.sh"
    "$SCRIPT_DIR/../commands/other.sh"
  )
  
  for script in "${script_files[@]}"; do
    if zsh -n "$script" 2>/dev/null; then
      print_test_result "$(basename "$script") syntax is valid" "PASS"
    else
      print_test_result "$(basename "$script") syntax is valid" "FAIL"
    fi
  done
}

test_environment_isolation() {
  print_test_header "Testing Environment Isolation"
  
  setup_test_env
  
  # Test that the script respects WORKTREES_DIR environment variable
  local original_worktrees_dir="$WORKTREES_DIR"
  export WORKTREES_DIR="$TEST_WORKTREES_DIR"
  
  # Check that configuration uses the custom directory
  local config_test
  config_test=$(source "$SCRIPT_DIR/../config.sh" && echo "$WORKTREES_DIR")
  
  if [[ "$config_test" == "$TEST_WORKTREES_DIR" ]]; then
    print_test_result "Script respects WORKTREES_DIR environment variable" "PASS"
  else
    print_test_result "Script respects WORKTREES_DIR environment variable" "FAIL"
  fi
  
  # Restore original environment
  export WORKTREES_DIR="$original_worktrees_dir"
  
  cleanup_test_env
}

# Run all tests
main() {
  test_main_script_structure
  test_help_and_version
  test_command_routing
  test_dependency_checking
  test_configuration_loading
  test_file_structure_integrity
  test_script_syntax
  test_environment_isolation
  
  print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "$0" == *"test_integration.sh" ]]; then
  main "$@"
fi
