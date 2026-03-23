#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Test runner for condition system tests
# Runs both unit tests and integration tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEST_DIR="$SCRIPT_DIR"

# Function to run AWK test
run_awk_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .awk)
    
    echo "Running $test_name..."
    
    # Preprocess the test file to expand @include directives
    local preprocessed="/tmp/dap_tpl_condition_test_$$.awk"
    if ! AWKPATH="${DAP_TPL_ROOT}" "${DAP_TPL_ROOT}/utils/awk_include_preprocessor.sh" "$test_file" "${DAP_TPL_ROOT}" > "$preprocessed" 2>/dev/null; then
        echo -e "${RED}✗${NC} $test_name failed (preprocessing)"
        ((FAILED_TESTS++))
        rm -f "$preprocessed"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        return 1
    fi
    
    # Run preprocessed test
    if "$AWK_CMD" $AWK_EXTRA_ARGS -f "$preprocessed" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $test_name passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        rm -f "$preprocessed"
    else
        echo -e "${RED}✗${NC} $test_name failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        # Run again to show errors
        echo "Errors:"
        "$AWK_CMD" $AWK_EXTRA_ARGS -f "$preprocessed" || true
        rm -f "$preprocessed"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

echo "================================="
echo "  Condition System Test Suite"
echo "================================="
echo ""
echo "DAP_TPL_ROOT: $DAP_TPL_ROOT"
echo "TEST_DIR: $TEST_DIR"
echo ""

# Change to dap_tpl root for proper @include paths
cd "$DAP_TPL_ROOT"

echo "--- Unit Tests ---"
echo ""

# Run unit tests for each condition type
echo "Testing logical operators..."
run_awk_test "$TEST_DIR/logical/test_and_parser.awk"

echo ""
echo "Testing comparison operators..."
run_awk_test "$TEST_DIR/comparison/test_comparison_parser.awk"

echo ""
echo "Testing special operators..."
run_awk_test "$TEST_DIR/special/test_contains_parser.awk"
run_awk_test "$TEST_DIR/special/test_not_contains_parser.awk"
run_awk_test "$TEST_DIR/special/test_not_contains_evaluator.awk"
run_awk_test "$TEST_DIR/special/test_matches_parser.awk"

echo ""
echo "Testing simple variable..."
run_awk_test "$TEST_DIR/simple/test_simple_parser.awk"

echo ""
echo "--- Integration Tests ---"
echo ""
run_awk_test "$TEST_DIR/integration/test_condition_integration.awk"

echo ""
echo "================================="
echo "  Test Results"
echo "================================="
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi
