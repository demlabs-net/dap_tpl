#!/bin/bash
# Integration test for nested if conditions in for loop bug
# This test reproduces the bug where {{#if type == 'void'}} always returns true
# when used inside {{#for type in RETURN_TYPES}} with nested {{#if macro_name}}

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
TEMPLATES_DIR="${TEST_DIR}/fixtures"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR
export AWKPATH="${DAP_TPL_DIR}"

mkdir -p "${TEST_DIR}/fixtures"

# Build engine and capture path
ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" ../mocks/lib/dap_tpl 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
    echo "ERROR: Failed to build engine or find engine file"
    echo "$ENGINE_OUTPUT"
    exit 1
fi

# Create test template that reproduces the bug
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_nested_if_in_for.tpl"
cat > "$TEST_TEMPLATE" << 'EOF'
{{#for type in RETURN_TYPES}}
    {{#set macro_name={{type|sanitize_name}}}}
    {{#if macro_name}}
        // Processing type: {{type}}
        {{#if type == 'void'}}
            VOID_BRANCH: {{type}}
        {{else}}
            NON_VOID_BRANCH: {{type}}
        {{/if}}
    {{/if}}
{{/for}}
EOF

echo "Test 1: RETURN_TYPES='void int' - should have 1 VOID and 1 NON-VOID"
export RETURN_TYPES="void int"
OUTPUT=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)

# Check that void goes to VOID branch
if ! echo "$OUTPUT" | grep -q "VOID_BRANCH: void"; then
    echo "FAIL: void should go to VOID_BRANCH"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Check that int goes to NON-VOID branch
if ! echo "$OUTPUT" | grep -q "NON_VOID_BRANCH: int"; then
    echo "FAIL: int should go to NON_VOID_BRANCH"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Check that void does NOT go to NON-VOID branch
if echo "$OUTPUT" | grep -q "NON_VOID_BRANCH: void"; then
    echo "FAIL: void should NOT go to NON_VOID_BRANCH"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Check that int does NOT go to VOID branch
if echo "$OUTPUT" | grep -q "VOID_BRANCH: int"; then
    echo "FAIL: int should NOT go to VOID_BRANCH"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

echo "PASS: Test 1 - void and int correctly routed"

echo ""
echo "Test 2: RETURN_TYPES='void int char' - should have 1 VOID and 2 NON-VOID"
export RETURN_TYPES="void int char"
OUTPUT2=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)

# Count occurrences
VOID_COUNT=$(echo "$OUTPUT2" | grep -cE "^[[:space:]]*VOID_BRANCH:" || echo "0")
NON_VOID_COUNT=$(echo "$OUTPUT2" | grep -cE "^[[:space:]]*NON_VOID_BRANCH:" || echo "0")

if [ "$VOID_COUNT" != "1" ]; then
    echo "FAIL: Expected exactly 1 VOID_BRANCH, got $VOID_COUNT"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

if [ "$NON_VOID_COUNT" != "2" ]; then
    echo "FAIL: Expected exactly 2 NON_VOID_BRANCH, got $NON_VOID_COUNT"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

echo "PASS: Test 2 - correct branch counts"

echo ""
echo "Test 3: RETURN_TYPES='int char' - should have 0 VOID and 2 NON-VOID"
export RETURN_TYPES="int char"
OUTPUT3=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)

VOID_COUNT=$(echo "$OUTPUT3" | grep -cE "^[[:space:]]*VOID_BRANCH:" || echo "0")
NON_VOID_COUNT=$(echo "$OUTPUT3" | grep -cE "^[[:space:]]*NON_VOID_BRANCH:" || echo "0")

if [ "$VOID_COUNT" != "0" ]; then
    echo "FAIL: Expected 0 VOID_BRANCH, got $VOID_COUNT"
    echo "Output:"
    echo "$OUTPUT3" | cat -A
    exit 1
fi

if [ "$NON_VOID_COUNT" != "2" ]; then
    echo "FAIL: Expected exactly 2 NON_VOID_BRANCH, got $NON_VOID_COUNT"
    echo "Output:"
    echo "$OUTPUT3" | cat -A
    exit 1
fi

echo "PASS: Test 3 - no void types correctly handled"

rm -f "${TEST_TEMPLATE}"
echo ""
echo "=========================================="
echo "ALL INTEGRATION TESTS PASSED"
echo "=========================================="

