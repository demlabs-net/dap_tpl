#!/bin/bash
# Integration test: Reproduce real issue from return_type_macros.h.tpl
# This test reproduces the exact problem where #set directives remain in output

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATES_DIR="$(cd "${DAP_TPL_DIR}/../templates" && pwd)"

TEST_TEMPLATE="${TEMPLATES_DIR}/return_type_macros.h.tpl"
TEST_OUTPUT="/tmp/test_real_issue_output.h"

# Load dap_tpl functions
cd "${DAP_TPL_DIR}"
source dap_tpl.sh

# Build engine with extensions
EXTENSIONS_DIR="${DAP_TPL_DIR}/../mocks/lib/dap_tpl"
ENGINE_OUTPUT=$(./utils/build_engine.sh "${EXTENSIONS_DIR}" 2>&1)
ENGINE_PATH=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2)

if [ -z "$ENGINE_PATH" ] || [ ! -f "$ENGINE_PATH" ]; then
    echo "FAIL: Engine not built"
    exit 1
fi

echo "Using engine: $ENGINE_PATH"
echo ""

# Test with RETURN_TYPES set (should process normally)
echo "=========================================="
echo "TEST 1: RETURN_TYPES=int (should work)"
echo "=========================================="
export RETURN_TYPES="int"
export ORIGINAL_TYPES_DATA="int|int"
export BASIC_TYPES_RAW_DATA="int|int"

gawk -f "$ENGINE_PATH" "$TEST_TEMPLATE" > "${TEST_OUTPUT}" 2>&1

if grep -q "#set NORMALIZATION_MACROS_DATA" "${TEST_OUTPUT}"; then
    echo "FAIL: Output contains #set NORMALIZATION_MACROS_DATA directive"
    grep -n "#set" "${TEST_OUTPUT}" | head -5
    echo ""
    echo "Context around problem:"
    grep -C3 "#set NORMALIZATION_MACROS_DATA" "${TEST_OUTPUT}" | head -10
    exit 1
fi

if grep -q "#set TYPE_TO_SELECT_DATA" "${TEST_OUTPUT}"; then
    echo "FAIL: Output contains #set TYPE_TO_SELECT_DATA directive"
    grep -n "#set" "${TEST_OUTPUT}" | head -5
    exit 1
fi

if grep -q "#set BASIC_TYPES_DATA" "${TEST_OUTPUT}"; then
    echo "FAIL: Output contains #set BASIC_TYPES_DATA directive"
    grep -n "#set" "${TEST_OUTPUT}" | head -5
    exit 1
fi

echo "PASS: No #set directives in output"
echo ""

# Test without RETURN_TYPES (should skip entire block)
echo "=========================================="
echo "TEST 2: RETURN_TYPES unset (should skip)"
echo "=========================================="
unset RETURN_TYPES
unset ORIGINAL_TYPES_DATA
unset BASIC_TYPES_RAW_DATA

gawk -f "$ENGINE_PATH" "$TEST_TEMPLATE" > "${TEST_OUTPUT}" 2>&1

if grep -q "#set" "${TEST_OUTPUT}"; then
    echo "FAIL: Output contains #set directives when RETURN_TYPES is unset"
    grep -n "#set" "${TEST_OUTPUT}"
    echo ""
    echo "Full output:"
    cat "${TEST_OUTPUT}"
    exit 1
fi

echo "PASS: No #set directives when RETURN_TYPES unset"
echo ""

rm -f "${TEST_OUTPUT}"
echo "=========================================="
echo "ALL TESTS PASSED"
echo "=========================================="

