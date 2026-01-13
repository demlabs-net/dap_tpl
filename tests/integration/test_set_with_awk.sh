#!/bin/bash
# Integration test: set with AWK sections
# Tests that #set directives with AWK sections don't appear in final output
# This reproduces the issue where #set directives remain in generated C code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_TEMPLATE="${SCRIPT_DIR}/test_set_with_awk.tpl"
TEST_OUTPUT="/tmp/test_set_with_awk_output.txt"
EXPECTED_OUTPUT="/tmp/test_set_with_awk_expected.txt"

# Use compiled engine directly
ENGINE_FILE="${DAP_TPL_DIR}/utils/build_engine.sh"

# Expected output (should NOT contain #set directives)
cat > "${EXPECTED_OUTPUT}" <<'EOF'

Value: test_output


Data: data1|data2


EOF

# Build engine and run
cd "${DAP_TPL_DIR}"
ENGINE_PATH=$(EXTENSIONS_DIR=../mocks/lib/dap_tpl ./utils/build_engine.sh 2>&1 | grep "^ENGINE_PATH=" | cut -d'=' -f2)
if [ -z "${ENGINE_PATH}" ] || [ ! -f "${ENGINE_PATH}" ]; then
    echo "FAIL: Failed to build engine"
    exit 1
fi

echo "Using engine: ${ENGINE_PATH}"

# Run template through engine with proper AWKPATH (check both stdout and stderr separately)
(cd "${DAP_TPL_DIR}" && \
 env AWKPATH="${DAP_TPL_DIR}" DEBUG_ENABLED=0 mawk -f "${ENGINE_PATH}" "${TEST_TEMPLATE}" > "${TEST_OUTPUT}" 2>"${TEST_OUTPUT}.stderr") || {
    echo "FAIL: Template processing failed"
    cat "${TEST_OUTPUT}"
    if [ -s "${TEST_OUTPUT}.stderr" ]; then
        echo "Stderr:"
        cat "${TEST_OUTPUT}.stderr"
    fi
    exit 1
}

# Check stderr is empty (no errors)
if [ -s "${TEST_OUTPUT}.stderr" ]; then
    echo "FAIL: Unexpected output in stderr:"
    cat "${TEST_OUTPUT}.stderr"
    exit 1
fi
rm -f "${TEST_OUTPUT}.stderr"

# Check if output contains #set directives (should NOT)
if grep -q "#set" "${TEST_OUTPUT}"; then
    echo "FAIL: Output contains #set directives (should be removed)"
    echo "Found #set directives:"
    grep -n "#set" "${TEST_OUTPUT}"
    echo ""
    echo "Full output:"
    cat "${TEST_OUTPUT}"
    exit 1
fi

# Check main content (ignoring trailing whitespace differences)
if ! grep -q "Value: test_output" "${TEST_OUTPUT}"; then
    echo "FAIL: Missing 'Value: test_output' in output"
    exit 1
fi

if ! grep -q "Data: data1|data2" "${TEST_OUTPUT}"; then
    echo "FAIL: Missing 'Data: data1|data2' in output"
    exit 1
fi

echo "PASS: set with AWK sections works correctly"
rm -f "${TEST_OUTPUT}" "${EXPECTED_OUTPUT}"

