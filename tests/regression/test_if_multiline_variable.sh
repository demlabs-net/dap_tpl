#!/bin/bash
# Regression test for {{#if}} with multiline variables and parallel execution
# This test verifies that {{#if VARIABLE}} correctly evaluates multiline
# variables as non-empty (truthy), fixing the bug where multiline variables
# passed through replace_template_placeholders were not visible in AWK.
#
# Bug: When using MAP_IMPL_COND_DATA with newline-separated values in
# replace_template_placeholders, the {{#if MAP_IMPL_COND_DATA}} condition
# returned false, causing the entire block to be skipped.
# 
# Root cause: Race condition in parallel builds:
# 1. build_engine.sh wrote directly to final file, causing partial reads
# 2. include evaluator used non-unique temp file names (rand() without srand())
#
# Fixed by:
# 1. Atomic file write in build_engine.sh (temp file + mv)
# 2. Unique temp file names using PID + timestamp in include evaluator
# 3. srand() initialization in main_pipeline.awk

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
TEMPLATES_DIR="${TEST_DIR}/fixtures"

# Source the main dap_tpl library
source "${DAP_TPL_DIR}/dap_tpl.sh"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR
export AWKPATH="${DAP_TPL_DIR}"

mkdir -p "${TEST_DIR}/fixtures"

echo "=========================================="
echo "Regression Test: {{#if}} with multiline variables"
echo "=========================================="

# Test 1: Reproducing EXACT scenario from dap_mock_generate.sh
# where variable is set in environment AND passed as argument using "VAR=$VAR"
echo ""
echo "Test 1: {{#if}} with multiline variable (dap_mock_generate.sh pattern)"
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_if_multiline_basic.tpl"
cat > "$TEST_TEMPLATE" << 'EOF'
{{#if MAP_IMPL_COND_DATA}}
Variable is NOT empty
{{#for entry in MAP_IMPL_COND_DATA|newline}}
Entry: {{entry}}
{{/for}}
{{else}}
Variable IS empty
{{/if}}
EOF

TEST_OUTPUT="${TEST_DIR}/fixtures/test_if_multiline_basic.out"

# Set multiline variable (simulating MAP_IMPL_COND_DATA from mock generator)
MAP_IMPL_COND_DATA="3
5
1
2
4
0
6"

# CRITICAL: Reproduce the EXACT pattern from dap_mock_generate.sh lines 89-105
# Variables are set in command environment, then passed as "VAR=$VAR"
MAP_IMPL_COND_DATA="$MAP_IMPL_COND_DATA" \
replace_template_placeholders "$TEST_TEMPLATE" "$TEST_OUTPUT" \
    "MAP_IMPL_COND_DATA=$MAP_IMPL_COND_DATA"

# Check output
if ! grep -q "Variable is NOT empty" "$TEST_OUTPUT"; then
    echo "FAIL: {{#if}} should detect non-empty multiline variable"
    echo "Expected: 'Variable is NOT empty'"
    echo "Got:"
    cat "$TEST_OUTPUT"
    exit 1
fi

if grep -q "Variable IS empty" "$TEST_OUTPUT"; then
    echo "FAIL: {{#else}} branch should not execute"
    echo "Got:"
    cat "$TEST_OUTPUT"
    exit 1
fi

# Check that for loop processed all entries
for num in 3 5 1 2 4 0 6; do
    if ! grep -q "Entry: $num" "$TEST_OUTPUT"; then
        echo "FAIL: Entry $num should be in output"
        echo "Got:"
        cat "$TEST_OUTPUT"
        exit 1
    fi
done

ENTRY_COUNT=$(grep -c "^Entry:" "$TEST_OUTPUT" || echo "0")
if [ "$ENTRY_COUNT" != "7" ]; then
    echo "FAIL: Expected exactly 7 entries, got $ENTRY_COUNT"
    echo "Got:"
    cat "$TEST_OUTPUT"
    exit 1
fi

echo "PASS: {{#if}} correctly detects non-empty multiline variable"

# Test 2: Verify empty variable is detected as false
echo ""
echo "Test 2: {{#if}} should detect empty variable"
TEST_TEMPLATE2="${TEST_DIR}/fixtures/test_if_empty.tpl"
cat > "$TEST_TEMPLATE2" << 'EOF'
{{#if EMPTY_VAR}}
Variable is NOT empty
{{else}}
Variable IS empty
{{/if}}
EOF

TEST_OUTPUT2="${TEST_DIR}/fixtures/test_if_empty.out"
replace_template_placeholders "$TEST_TEMPLATE2" "$TEST_OUTPUT2" "EMPTY_VAR="

if ! grep -q "Variable IS empty" "$TEST_OUTPUT2"; then
    echo "FAIL: {{#if}} should detect empty variable"
    echo "Got:"
    cat "$TEST_OUTPUT2"
    exit 1
fi

if grep -q "Variable is NOT empty" "$TEST_OUTPUT2"; then
    echo "FAIL: {{#if}} branch should not execute for empty variable"
    echo "Got:"
    cat "$TEST_OUTPUT2"
    exit 1
fi

echo "PASS: {{#if}} correctly detects empty variable"

# Test 3: Verify single-line non-empty variable
echo ""
echo "Test 3: {{#if}} should detect non-empty single-line variable"
TEST_TEMPLATE3="${TEST_DIR}/fixtures/test_if_singleline.tpl"
cat > "$TEST_TEMPLATE3" << 'EOF'
{{#if SINGLE_VAR}}
Variable is NOT empty: {{SINGLE_VAR}}
{{else}}
Variable IS empty
{{/if}}
EOF

TEST_OUTPUT3="${TEST_DIR}/fixtures/test_if_singleline.out"
replace_template_placeholders "$TEST_TEMPLATE3" "$TEST_OUTPUT3" "SINGLE_VAR=test123"

if ! grep -q "Variable is NOT empty: test123" "$TEST_OUTPUT3"; then
    echo "FAIL: {{#if}} should detect non-empty single-line variable"
    echo "Got:"
    cat "$TEST_OUTPUT3"
    exit 1
fi

echo "PASS: {{#if}} correctly detects non-empty single-line variable"

# Cleanup
rm -f "$TEST_OUTPUT" "$TEST_OUTPUT2" "$TEST_OUTPUT3"

echo ""
echo "=========================================="
echo "All tests PASSED"
echo "=========================================="
