#!/bin/zsh
# ===================================================================
# test_jira.sh - Tests for JIRA Integration Functions
# ===================================================================

# Source the test framework and required modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"
source "$SCRIPT_DIR/../config.sh"
source "$SCRIPT_DIR/../lib/core.sh"
source "$SCRIPT_DIR/../lib/jira.sh"

test_jira_pattern_matching() {
  print_test_header "Testing JIRA Pattern Matching"
  
  # Test valid JIRA patterns
  if [[ "ABC-123" =~ $JIRA_PATTERN ]]; then
    print_test_result "JIRA pattern matches ABC-123" "PASS"
  else
    print_test_result "JIRA pattern matches ABC-123" "FAIL"
  fi
  
  if [[ "PROJECT-456" =~ $JIRA_PATTERN ]]; then
    print_test_result "JIRA pattern matches PROJECT-456" "PASS"
  else
    print_test_result "JIRA pattern matches PROJECT-456" "FAIL"
  fi
  
  if [[ "XYZ-1" =~ $JIRA_PATTERN ]]; then
    print_test_result "JIRA pattern matches XYZ-1" "PASS"
  else
    print_test_result "JIRA pattern matches XYZ-1" "FAIL"
  fi
  
  # Test invalid JIRA patterns
  if [[ "abc-123" =~ $JIRA_PATTERN ]]; then
    print_test_result "JIRA pattern rejects lowercase abc-123" "FAIL"
  else
    print_test_result "JIRA pattern rejects lowercase abc-123" "PASS"
  fi
  
  if [[ "ABC123" =~ $JIRA_PATTERN ]]; then
    print_test_result "JIRA pattern rejects ABC123 (no dash)" "FAIL"
  else
    print_test_result "JIRA pattern rejects ABC123 (no dash)" "PASS"
  fi
  
  if [[ "123-ABC" =~ $JIRA_PATTERN ]]; then
    print_test_result "JIRA pattern rejects 123-ABC (numbers first)" "FAIL"
  else
    print_test_result "JIRA pattern rejects 123-ABC (numbers first)" "PASS"
  fi
}

test_jira_summary_extraction() {
  print_test_header "Testing JIRA Summary Functions"
  
  # Mock the jira command for testing
  jira() {
    mock_jira "$@"
  }
  
  # Test get_jira_summary with valid ticket
  local summary_result
  summary_result=$(get_jira_summary "ABC-123" 2>/dev/null)
  assert_contains "$summary_result" "Test JIRA ticket summary" "get_jira_summary returns summary"
  
  # Test get_jira_summary with empty ticket
  assert_command_failure "get_jira_summary ''" "get_jira_summary fails with empty ticket"
  
  # Test clean_jira_summary function
  local cleaned
  cleaned=$(clean_jira_summary "Fix User Authentication & Login Issues")
  assert_equals "fix-user-authentication-login-issues" "$cleaned" "clean_jira_summary cleans special characters"
  
  cleaned=$(clean_jira_summary "UPPERCASE TITLE WITH SPACES")
  assert_equals "uppercase-title-with-spaces" "$cleaned" "clean_jira_summary converts to lowercase"
  
  cleaned=$(clean_jira_summary "Multiple---Dashes & Symbols!!!")
  assert_equals "multiple-dashes-symbols" "$cleaned" "clean_jira_summary handles multiple dashes and symbols"
}

test_jira_branch_generation() {
  print_test_header "Testing JIRA Branch Name Generation"
  
  # Mock the jira command for testing
  jira() {
    case "$3" in
      "ABC-123")
        echo "Summary: Fix user authentication issues"
        ;;
      "XYZ-456")
        echo "Summary: Add new dashboard feature"
        ;;
      *)
        return 1
        ;;
    esac
  }
  
  # Test create_branch_from_jira
  local branch_name
  branch_name=$(create_branch_from_jira "ABC-123" 2>/dev/null)
  assert_equals "ABC-123-fix-user-authentication-issues" "$branch_name" "create_branch_from_jira generates correct branch name"
  
  branch_name=$(create_branch_from_jira "XYZ-456" 2>/dev/null)
  assert_equals "XYZ-456-add-new-dashboard-feature" "$branch_name" "create_branch_from_jira handles different tickets"
  
  # Test with invalid ticket
  branch_name=$(create_branch_from_jira "INVALID-999" 2>/dev/null)
  assert_equals "INVALID-999" "$branch_name" "create_branch_from_jira falls back to ticket number for invalid tickets"
}

test_jira_integration_workflow() {
  print_test_header "Testing JIRA Integration Workflow"
  
  # Test full workflow: ticket validation -> summary fetch -> branch creation
  local ticket="ABC-123"
  
  # Validate ticket format
  if [[ "$ticket" =~ $JIRA_PATTERN ]]; then
    print_test_result "Ticket format validation" "PASS" "ABC-123 is valid JIRA format"
  else
    print_test_result "Ticket format validation" "FAIL" "ABC-123 should be valid JIRA format"
  fi
  
  # Mock jira for workflow test
  jira() {
    if [[ "$1" == "issue" && "$2" == "view" && "$3" == "ABC-123" ]]; then
      echo "Summary: Implement user session management"
      return 0
    else
      return 1
    fi
  }
  
  # Test the complete workflow
  local workflow_result
  workflow_result=$(get_jira_summary "$ticket" 2>/dev/null)
  if [[ -n "$workflow_result" ]]; then
    local clean_summary
    clean_summary=$(clean_jira_summary "$workflow_result")
    local final_branch="${ticket}-${clean_summary}"
    assert_equals "ABC-123-implement-user-session-management" "$final_branch" "Complete JIRA workflow produces correct branch name"
  else
    print_test_result "Complete JIRA workflow" "FAIL" "Could not get JIRA summary"
  fi
}

# Run all tests
main() {
  test_jira_pattern_matching
  test_jira_summary_extraction
  test_jira_branch_generation
  test_jira_integration_workflow
  
  print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "$0" == *"test_jira.sh" ]]; then
  main "$@"
fi
