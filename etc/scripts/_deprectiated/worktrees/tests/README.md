# Worktree Management System Test Suite

This directory contains comprehensive tests for the modular worktree management system.

## Test Structure

### Test Files

- **`test_framework.sh`** - Core testing framework with assertion functions
- **`test_core.sh`** - Tests for core utility functions (print_color, check_tool, etc.)
- **`test_jira.sh`** - Tests for JIRA integration and pattern matching
- **`test_commands.sh`** - Tests for worktree command functions (create, delete, etc.)
- **`test_integration.sh`** - Integration tests for the main script and workflow
- **`run_tests.sh`** - Test runner that executes all tests

## Running Tests

### Run All Tests
```bash
./run_tests.sh
```

### Run Specific Test Categories
```bash
./run_tests.sh core          # Core functions only
./run_tests.sh jira          # JIRA integration only
./run_tests.sh commands      # Command functions only
./run_tests.sh integration   # Integration tests only
```

### List Available Tests
```bash
./run_tests.sh --list
```

### Get Help
```bash
./run_tests.sh --help
```

## Test Categories

### 1. Core Function Tests (`test_core.sh`)
- **print_color**: Color output functionality
- **check_tool**: Dependency checking
- **select_fzf**: Interactive selection (mocked)
- **detect_package_manager**: Package manager detection
- **find_main_branch**: Git main branch detection
- **validation functions**: Input validation

### 2. JIRA Integration Tests (`test_jira.sh`)
- **Pattern matching**: JIRA ticket format validation
- **Summary extraction**: Fetching ticket summaries
- **Branch generation**: Creating branch names from tickets
- **Integration workflow**: Complete JIRA-to-branch workflow

### 3. Command Function Tests (`test_commands.sh`)
- **Function existence**: All command functions are properly defined
- **Error handling**: Graceful handling of missing dependencies
- **Parameter validation**: Input parameter checking
- **Integration**: Command workflow testing

### 4. Integration Tests (`test_integration.sh`)
- **Script structure**: Main script exists and is executable
- **Help/version**: Command-line interface testing
- **Command routing**: Proper command dispatching
- **Dependency checking**: Real-world dependency validation
- **Configuration loading**: Config file integration
- **Syntax validation**: Script syntax checking

## Test Framework Features

### Assertion Functions
- `assert_equals(expected, actual, test_name)`
- `assert_not_equals(not_expected, actual, test_name)`
- `assert_command_success(command, test_name)`
- `assert_command_failure(command, test_name)`
- `assert_file_exists(file_path, test_name)`
- `assert_directory_exists(dir_path, test_name)`
- `assert_contains(haystack, needle, test_name)`

### Test Environment
- Isolated test directories (`/tmp/worktree_tests_*`)
- Mock git repositories for testing
- Cleanup functions for test isolation
- Mock functions for external dependencies

### Output Features
- Colored test output for better readability
- Test progress tracking
- Detailed failure messages
- Summary reports with pass/fail counts

## Example Test Output

```
╔══════════════════════════════════════════════════════════════════╗
║ Running test_core                                                ║
╚══════════════════════════════════════════════════════════════════╝

========================================
Testing Core Utility Functions
========================================
✅ PASS: print_color outputs message
✅ PASS: check_tool succeeds for git
✅ PASS: check_tool fails for non-existent tool

========================================
TEST SUMMARY
========================================
Total Tests: 15
Passed: 15
Failed: 0
🎉 All tests passed!
```

## Adding New Tests

### 1. Create a new test file
```bash
cp test_core.sh test_new_feature.sh
```

### 2. Update the test content
- Modify the test functions
- Add to `run_tests.sh` TEST_FILES array

### 3. Test framework usage
```bash
#!/bin/zsh
source "$(dirname "$0")/test_framework.sh"

test_my_feature() {
  print_test_header "Testing My Feature"
  
  # Your test code here
  assert_equals "expected" "actual" "My test description"
}

main() {
  test_my_feature
  print_test_summary
}

if [[ "$0" == *"test_new_feature.sh" ]]; then
  main "$@"
fi
```

## Continuous Testing

You can add this to your workflow:

```bash
# Run tests before committing
alias test-worktrees='cd /path/to/worktrees/tests && ./run_tests.sh'

# Quick test during development
alias test-core='cd /path/to/worktrees/tests && ./run_tests.sh core'
```

## Test Philosophy

The test suite follows these principles:

1. **Isolation**: Each test runs in its own environment
2. **Mocking**: External dependencies are mocked for reliability
3. **Coverage**: Tests cover both success and failure scenarios
4. **Readability**: Clear test names and descriptive output
5. **Maintainability**: Easy to add new tests and modify existing ones

## Contributing

When adding new features to the worktree system:

1. Write tests for new functions
2. Update existing tests if behavior changes
3. Run the full test suite before submitting changes
4. Ensure all tests pass

## Dependencies

The test suite requires:
- **zsh** - Shell for running tests
- **git** - For git-related functionality testing
- Standard Unix tools (grep, sed, etc.)

Optional dependencies for full testing:
- **fzf** - For interactive selection testing
- **jira** - For JIRA integration testing (mocked if not available)
