#!/bin/bash
# Integration test for macro system

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common test fixtures
source "${TEST_DIR}/fixtures/test_common.sh"

# Initialize test environment
init_test_env "$TEST_DIR"

# Test template
TEST_TEMPLATE="${FIXTURES_DIR}/test_macro.tpl"

# Expected output
EXPECTED="Hello, World! Welcome to DAP TPL.

Value is true: test
"

# Run template
TEMP_STDOUT=""
TEMP_STDERR=""
OUTPUT=""
STDERR_OUTPUT=""

if ! run_template "$TEST_TEMPLATE" TEMP_STDOUT TEMP_STDERR OUTPUT STDERR_OUTPUT; then
    echo "FAIL: Template processing failed"
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
if ! compare_outputs "$OUTPUT" "$EXPECTED" "macro system"; then
    cleanup_temp_files "$TEMP_STDOUT" "$TEMP_STDERR"
    exit 1
fi

# Cleanup
cleanup_temp_files "$TEMP_STDOUT" "$TEMP_STDERR"

echo "PASS"

