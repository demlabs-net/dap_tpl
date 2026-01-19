#!/bin/bash
# Test runner for condition system tests
# Runs tests from all condition subdirectories

set -e

# Source test helpers
source "$(dirname "${BASH_SOURCE[0]}")/../../fixtures/test_helpers.sh"

# Initialize test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_test_environment "$TEST_DIR"

# Initialize counters
init_test_counters

echo "Running condition system tests..."

# Run tests from each subdirectory
for test_subdir in comparison logical simple special integration; do
    if [ -d "${TEST_DIR}/${test_subdir}" ]; then
        echo ""
        echo "  ${test_subdir} tests:"
        run_tests_in_dir "${TEST_DIR}/${test_subdir}"
    fi
done

# Print results and exit
echo ""
print_test_results "condition tests" "conditions"
exit $?
