#!/bin/bash
# Test runner for marker_parser.awk tests
# Scans marker_parser_tests/ directory and runs all .awk test files

set -e

# Source test helpers
source "$(dirname "${BASH_SOURCE[0]}")/../../fixtures/test_helpers.sh"

# Initialize test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_test_environment "$TEST_DIR"

# Initialize counters
init_test_counters

echo "Running marker_parser tests..."

# Run all tests in marker_parser_tests directory
run_tests_in_dir "${TEST_DIR}/marker_parser_tests"

# Print results and exit
print_test_results "marker_parser tests" "marker_parser"
exit $?
