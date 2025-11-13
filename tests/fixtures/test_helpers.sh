#!/bin/bash
# Common test helper functions for dap_tpl unit tests
# Source this file in test scripts: source "$(dirname "${BASH_SOURCE[0]}")/../fixtures/test_helpers.sh"

# Initialize test environment
# Sets up paths and exports environment variables
# Parameters:
#   $1 - test directory (default: current script directory)
#   $2 - tests directory (default: parent of test directory)
# Returns: sets TEST_DIR, DAP_TPL_DIR, TESTS_DIR, SCRIPTS_DIR, AWKPATH
init_test_environment() {
    # Get the directory of the script that sourced this helper
    # BASH_SOURCE array: [0]=test_helpers.sh, [1]=calling script
    local caller_dir
    if [ ${#BASH_SOURCE[@]} -ge 2 ] && [ -n "${BASH_SOURCE[1]}" ]; then
        # Called from a script that sourced this file
        caller_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    else
        # Called directly or from command line
        caller_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    fi
    
    local test_dir="${1:-$caller_dir}"
    # TESTS_DIR should be the tests/ directory (parent of unit/)
    local tests_dir="${2:-$(cd "$test_dir/../.." && pwd)}"
    
    TEST_DIR="$test_dir"
    DAP_TPL_DIR="$(cd "$TEST_DIR/../../.." && pwd)"
    TESTS_DIR="$tests_dir"
    
    export SCRIPTS_DIR="${DAP_TPL_DIR}"
    # AWKPATH should include dap_tpl, tests, and tests/fixtures directories
    export AWKPATH="${DAP_TPL_DIR}:${TESTS_DIR}:${TESTS_DIR}/fixtures"
}

# Run a single AWK test file
# Parameters:
#   $1 - test file path
#   $2 - test name (optional, defaults to basename of file)
#   $3 - indent prefix (optional, defaults to "  ")
# Returns: 0 on success, 1 on failure
# Side effects: increments passed/failed counters, prints result
run_awk_test() {
    local test_file="$1"
    local test_name="${2:-$(basename "$test_file" .awk)}"
    local indent="${3:-  }"
    
    if [ ! -f "$test_file" ]; then
        return 1
    fi
    
    echo -n "${indent}${test_name}: "
    
    local result
    if result=$(cd "$DAP_TPL_DIR" && gawk -f "$test_file" <<< "" 2>&1); then
        if echo "$result" | grep -q "^PASS$"; then
            echo "PASS"
            ((passed++)) || true
            return 0
        else
            echo "FAIL"
            echo "${indent}    Output: $result"
            ((failed++)) || true
            return 1
        fi
    else
        echo "FAIL"
        echo "${indent}    Error: $result"
        ((failed++)) || true
        return 1
    fi
}

# Run all AWK tests in a directory
# Parameters:
#   $1 - directory path containing test files
#   $2 - indent prefix (optional, defaults to "  ")
# Returns: number of failed tests
# Side effects: runs all tests, updates passed/failed counters
run_tests_in_dir() {
    local test_dir="$1"
    local indent="${2:-  }"
    local local_failed=0
    
    if [ ! -d "$test_dir" ]; then
        echo "ERROR: Test directory not found: $test_dir"
        return 1
    fi
    
    for test_file in "$test_dir"/*.awk; do
        if [ ! -f "$test_file" ]; then
            continue
        fi
        
        if ! run_awk_test "$test_file" "" "$indent"; then
            ((local_failed++)) || true
        fi
    done
    
    return $local_failed
}

# Print test results summary
# Parameters:
#   $1 - test suite name (optional, e.g., "evaluator tests")
#   $2 - test type name (optional, e.g., "evaluator", defaults to "test")
# Returns: exit code (0 if all passed, 1 if any failed)
print_test_results() {
    local suite_name="${1:-tests}"
    local test_type="${2:-test}"
    
    echo ""
    if [ $failed -eq 0 ]; then
        echo "All $passed ${test_type} tests passed!"
        return 0
    else
        echo "$failed ${test_type} test(s) failed, $passed ${test_type} test(s) passed"
        return 1
    fi
}

# Initialize counters
# Call this at the start of each test script
init_test_counters() {
    failed=0
    passed=0
}

