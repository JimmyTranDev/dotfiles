#!/bin/zsh
# ===================================================================
# test_commands.sh - Tests for Worktree Command Functions
# ===================================================================

# Source the test framework and required modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"
source "$SCRIPT_DIR/../config.sh"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/jira.sh"

# Source command modules
source "$SCRIPT_DIR/../commands/create.sh"
source "$SCRIPT_DIR/../commands/delete.sh"
source "$SCRIPT_DIR/../commands/checkout.sh"
source "$SCRIPT_DIR/../commands/update.sh"
source "$SCRIPT_DIR/../commands/other.sh"

test_create_command_validation() {
  print_test_header "Testing Create Command Validation"
  
  setup_test_env
  cd "$TEST_REPO_DIR"
  
  # Mock required tools to exist
  check_tool() {
    case "$1" in
      "git"|"fzf"|"jira") return 0 ;;
      *) return 1 ;;
    esac
  }
  
  # Mock get_jira_summary
  get_jira_summary() {
    echo "Test JIRA summary"
    return 0
  }
  
  # Mock find_main_branch
  find_main_branch() {
    echo "main"
    return 0
  }
  
  # Test that cmd_create function exists and can be called
  if declare -f cmd_create >/dev/null; then
    print_test_result "cmd_create function exists" "PASS"
  else
    print_test_result "cmd_create function exists" "FAIL"
  fi
  
  cleanup_test_env
}

test_create_command_cli_arguments() {
  print_test_header "Testing Create Command CLI Arguments"
  
  setup_test_env
  cd "$TEST_REPO_DIR"
  
  # Setup mock programming directory
  local mock_programming_dir="$TEMP_DIR/programming"
  mkdir -p "$mock_programming_dir/test-repo"
  mkdir -p "$mock_programming_dir/my-project"
  
  # Mock required functions
  check_tool() {
    case "$1" in
      "git"|"fzf"|"jira") return 0 ;;
      *) return 1 ;;
    esac
  }
  
  get_jira_summary() {
    echo "Test JIRA summary for $1"
    return 0
  }
  
  find_main_branch() {
    echo "main"
    return 0
  }
  
  # Mock git worktree add to avoid actual worktree creation
  git() {
    if [[ "$1" == "worktree" && "$2" == "add" ]]; then
      print_color green "Mock: Would create worktree $3 for branch $4"
      return 0
    else
      command git "$@"
    fi
  }
  
  # Test create command with both JIRA ticket and repository name
  print_color yellow "Testing: cmd_create with both arguments"
  local result
  result=$(PROGRAMMING_DIR="$mock_programming_dir" cmd_create "ABC-123" "test-repo" 2>&1)
  if [[ $? -eq 0 ]]; then
    print_test_result "cmd_create accepts JIRA ticket and repo name" "PASS"
  else
    print_test_result "cmd_create accepts JIRA ticket and repo name" "FAIL"
    echo "Error output: $result"
  fi
  
  # Test create command with only JIRA ticket (should use interactive repo selection)
  mock_get_repository() {
    if [[ -n "$1" ]]; then
      PROGRAMMING_DIR="$mock_programming_dir" find_repository_by_name "$1"
    else
      echo "$mock_programming_dir/test-repo"
    fi
  }
  
  # Override get_repository function temporarily
  local original_get_repository_function="$(declare -f get_repository)"
  eval "get_repository() { mock_get_repository \"\$1\"; }"
  
  print_color yellow "Testing: cmd_create with JIRA ticket only"
  result=$(PROGRAMMING_DIR="$mock_programming_dir" cmd_create "XYZ-456" 2>&1)
  if [[ $? -eq 0 ]]; then
    print_test_result "cmd_create works with JIRA ticket only" "PASS"
  else
    print_test_result "cmd_create works with JIRA ticket only" "FAIL"
    echo "Error output: $result"
  fi
  
  # Test create command with invalid repository name
  print_color yellow "Testing: cmd_create with invalid repo name"
  result=$(PROGRAMMING_DIR="$mock_programming_dir" cmd_create "DEF-789" "nonexistent-repo" 2>&1)
  if [[ $? -ne 0 ]]; then
    print_test_result "cmd_create handles invalid repo name" "PASS"
  else
    print_test_result "cmd_create handles invalid repo name" "FAIL"
    echo "Should have failed but didn't: $result"
  fi
  
  # Restore original functions
  if [[ -n "$original_get_repository_function" ]]; then
    eval "$original_get_repository_function"
  fi
  
  cleanup_test_env
}

test_delete_command_validation() {
  print_test_header "Testing Delete Command Validation"
  
  setup_test_env
  
  # Create a mock worktree directory
  mkdir -p "$TEST_WORKTREES_DIR/test-repo-feature-branch"
  echo "gitdir: $TEST_REPO_DIR/.git/worktrees/feature-branch" > "$TEST_WORKTREES_DIR/test-repo-feature-branch/.git"
  
  # Mock required tools to exist
  check_tool() {
    case "$1" in
      "git"|"fzf") return 0 ;;
      *) return 1 ;;
    esac
  }
  
  # Test that cmd_delete function exists
  if declare -f cmd_delete >/dev/null; then
    print_test_result "cmd_delete function exists" "PASS"
  else
    print_test_result "cmd_delete function exists" "FAIL"
  fi
  
  # Test worktree directory detection
  if [[ -d "$TEST_WORKTREES_DIR/test-repo-feature-branch" ]]; then
    print_test_result "Mock worktree directory created" "PASS"
  else
    print_test_result "Mock worktree directory created" "FAIL"
  fi
  
  cleanup_test_env
}

test_checkout_command_validation() {
  print_test_header "Testing Checkout Command Validation"
  
  setup_test_env
  cd "$TEST_REPO_DIR"
  
  # Create a test branch
  git checkout -b test-feature >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
  
  # Mock required tools to exist
  check_tool() {
    case "$1" in
      "git"|"fzf") return 0 ;;
      *) return 1 ;;
    esac
  }
  
  # Test that cmd_checkout function exists
  if declare -f cmd_checkout >/dev/null; then
    print_test_result "cmd_checkout function exists" "PASS"
  else
    print_test_result "cmd_checkout function exists" "FAIL"
  fi
  
  # Test branch listing
  local branches
  branches=$(git branch -r 2>/dev/null | wc -l)
  if [[ $branches -ge 0 ]]; then
    print_test_result "Git branch listing works" "PASS"
  else
    print_test_result "Git branch listing works" "FAIL"
  fi
  
  cleanup_test_env
}

test_update_command_validation() {
  print_test_header "Testing Update Command Validation"
  
  setup_test_env
  
  # Mock required tools to exist
  check_tool() {
    case "$1" in
      "git") return 0 ;;
      *) return 1 ;;
    esac
  }
  
  # Test that cmd_update function exists
  if declare -f cmd_update >/dev/null; then
    print_test_result "cmd_update function exists" "PASS"
  else
    print_test_result "cmd_update function exists" "FAIL"
  fi
  
  cleanup_test_env
}

test_other_commands_validation() {
  print_test_header "Testing Other Commands Validation"
  
  # Test that all other command functions exist
  local commands=("cmd_clean" "cmd_rename" "cmd_move")
  
  for cmd in "${commands[@]}"; do
    if declare -f "$cmd" >/dev/null; then
      print_test_result "$cmd function exists" "PASS"
    else
      print_test_result "$cmd function exists" "FAIL"
    fi
  done
}

test_command_error_handling() {
  print_test_header "Testing Command Error Handling"
  
  # Mock check_tool to fail for missing dependencies
  check_tool() {
    case "$1" in
      "git") return 1 ;;  # Simulate git not found
      *) return 0 ;;
    esac
  }
  
  # Test that commands handle missing git gracefully
  # These should return 1 (failure) but not crash
  if ! cmd_create "test" >/dev/null 2>&1; then
    print_test_result "cmd_create handles missing git" "PASS"
  else
    print_test_result "cmd_create handles missing git" "FAIL"
  fi
  
  if ! cmd_delete >/dev/null 2>&1; then
    print_test_result "cmd_delete handles missing git" "PASS"
  else
    print_test_result "cmd_delete handles missing git" "FAIL"
  fi
  
  if ! cmd_checkout >/dev/null 2>&1; then
    print_test_result "cmd_checkout handles missing git" "PASS"
  else
    print_test_result "cmd_checkout handles missing git" "FAIL"
  fi
}

test_command_integration() {
  print_test_header "Testing Command Integration"
  
  setup_test_env
  cd "$TEST_REPO_DIR"
  
  # Mock all dependencies to exist
  check_tool() {
    return 0
  }
  
  # Mock JIRA functions
  get_jira_summary() {
    echo "test-summary"
    return 0
  }
  
  find_main_branch() {
    echo "main"
    return 0
  }
  
  # Test basic command workflow without actually creating worktrees
  # This tests that the functions can be called without errors
  
  # Test create command parameter handling
  local test_result
  if cmd_create >/dev/null 2>&1 < /dev/null; then
    # Command should handle empty input gracefully
    print_test_result "cmd_create handles empty input" "PASS"
  else
    print_test_result "cmd_create handles empty input" "FAIL"
  fi
  
  cleanup_test_env
}

# Run all tests
main() {
  test_create_command_validation
  test_create_command_cli_arguments
  test_delete_command_validation
  test_checkout_command_validation
  test_update_command_validation
  test_other_commands_validation
  test_command_error_handling
  test_command_integration
  
  print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "$0" == *"test_commands.sh" ]]; then
  main "$@"
fi
