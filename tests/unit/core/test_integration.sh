#!/bin/bash
# Test runner for integration unit tests

set -e

# Source test helpers
source "$(dirname "${BASH_SOURCE[0]}")/../../fixtures/test_helpers.sh"

# Initialize test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_test_environment "$TEST_DIR"

# Initialize counters
init_test_counters

echo "Running integration unit tests..."

# Run all tests in integration_tests directory
run_tests_in_dir "$TEST_DIR/integration_tests"

# Print results and exit
print_test_results "integration unit tests" "integration"
exit $?

