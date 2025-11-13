#!/bin/bash
# Test runner for macro system tests

set -e

# Source test helpers
source "$(dirname "${BASH_SOURCE[0]}")/../../fixtures/test_helpers.sh"

# Initialize test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_test_environment "$TEST_DIR"

# Initialize counters
init_test_counters

echo "Running macro system tests..."

# Test macro_store.awk
run_awk_test "${TEST_DIR}/test_macro_store.awk" "test_macro_store"

# Print results and exit
print_test_results "macro system tests" "macro"
exit $?

