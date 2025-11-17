#!/bin/bash
# Integration test for elif support

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common test fixtures (from parent fixtures directory)
source "${TEST_DIR}/../fixtures/test_common.sh"

# Initialize test environment
init_test_env "$TEST_DIR"

# Test template
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_elif.tpl"

# Test function for a single elif test case
test_elif_case() {
    local var_value="$1"
    local expected_output="$2"
    local test_name="$3"
    
    export VAR="$var_value"
    
    # Run template
    TEMP_STDOUT=""
    TEMP_STDERR=""
    OUTPUT=""
    STDERR_OUTPUT=""
    
    if ! run_template "$TEST_TEMPLATE" TEMP_STDOUT TEMP_STDERR OUTPUT STDERR_OUTPUT; then
        echo "FAIL: Template processing failed for VAR=$var_value ($test_name)"
        cat "$TEMP_STDOUT"
        cat "$TEMP_STDERR" >&2
        cleanup_temp_files "$TEMP_STDOUT" "$TEMP_STDERR"
        exit 1
    fi
    
    # Check stderr is empty (no errors)
    if ! check_stderr_empty "$STDERR_OUTPUT"; then
        cleanup_temp_files "$TEMP_STDOUT" "$TEMP_STDERR"
        exit 1
    fi
    
    # Compare outputs
    if ! compare_outputs "$OUTPUT" "$expected_output" "elif test with VAR=$var_value ($test_name)"; then
        cleanup_temp_files "$TEMP_STDOUT" "$TEMP_STDERR"
        exit 1
    fi
    
    # Cleanup
    cleanup_temp_files "$TEMP_STDOUT" "$TEMP_STDERR"
}

# Test elif chain
echo "Test: elif chain"

# Test VAR=1
test_elif_case "1" "Value is 1" "first branch"

# Test VAR=2
test_elif_case "2" "Value is 2" "second branch"

# Test VAR=3
test_elif_case "3" "Value is 3" "third branch"

# Test VAR=5 (else branch)
test_elif_case "5" "Value is something else: 5" "else branch"

echo "PASS: elif chain tests"

