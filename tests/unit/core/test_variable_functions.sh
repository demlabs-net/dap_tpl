#!/bin/bash
# Test runner for variable_functions.awk tests
# Scans variable_functions_tests/ directory and runs all .awk test files

set -e

# Source test helpers
source "$(dirname "${BASH_SOURCE[0]}")/../../fixtures/test_helpers.sh"

# Initialize test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_test_environment "$TEST_DIR"

# Initialize counters
init_test_counters

TESTS_DIR="${TEST_DIR}/variable_functions_tests"

echo "Running variable_functions tests..."

# Test new name manipulation functions (only core functions, mocking functions moved to mocks/tests)
echo "  Testing core name manipulation functions..."
for func in remove_suffix trim; do
    test_file="${TESTS_DIR}/test_${func}_function.awk"
    if [ -f "$test_file" ]; then
        run_awk_test "$test_file" "" "    "
    fi
done

# Run all remaining tests in directory
run_tests_in_dir "$TESTS_DIR"

# Print results and exit
print_test_results "variable_functions tests" "variable_function"
exit $?
