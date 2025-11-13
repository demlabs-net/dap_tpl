#!/bin/bash
# Test runner for evaluator tests

set -e

# Source test helpers
source "$(dirname "${BASH_SOURCE[0]}")/../../fixtures/test_helpers.sh"

# Initialize test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_test_environment "$TEST_DIR"

# Initialize counters
init_test_counters

echo "Running evaluator tests..."

# Run all tests in evaluator_tests directory
run_tests_in_dir "$TEST_DIR/evaluator_tests"

# Print results and exit
print_test_results "evaluator tests" "evaluator"
exit $?

