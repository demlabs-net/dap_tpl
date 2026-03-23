#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Integration test for comparison conditions inside for loops
# This test reproduces the bug where 'type == \"void\"' always returns true

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
TEMPLATES_DIR="${TEST_DIR}/fixtures"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR
export AWKPATH="${DAP_TPL_DIR}"

mkdir -p "${TEST_DIR}/fixtures"

# Build engine and capture path
ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
    echo "ERROR: Failed to build engine or find engine file"
    echo "$ENGINE_OUTPUT"
    exit 1
fi

# Test 1: Comparison condition in for loop with void and int
echo "Test 1: Comparison condition in for loop"
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_for_comparison.tpl"
cat > "$TEST_TEMPLATE" << 'EOF'
{{#for type in RETURN_TYPES}}
    Type: {{type}}
    {{#if type == 'void'}}
        VOID BRANCH: {{type}}
    {{else}}
        NON-VOID BRANCH: {{type}}
    {{/if}}
{{/for}}
EOF

export RETURN_TYPES="void int"
OUTPUT=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>/dev/null)

# Check that void goes to VOID branch
if ! echo "$OUTPUT" | grep -q "VOID BRANCH: void"; then
    echo "FAIL: void should go to VOID branch"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Check that int goes to NON-VOID branch
if ! echo "$OUTPUT" | grep -q "NON-VOID BRANCH: int"; then
    echo "FAIL: int should go to NON-VOID branch"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Check that void does NOT go to NON-VOID branch
if echo "$OUTPUT" | grep -q "NON-VOID BRANCH: void"; then
    echo "FAIL: void should NOT go to NON-VOID branch"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Check that int does NOT go to VOID branch
# Check that there's no line containing both "VOID BRANCH" and "int" (without "NON-VOID")
if echo "$OUTPUT" | grep "VOID BRANCH" | grep -q "int" && ! echo "$OUTPUT" | grep "VOID BRANCH" | grep "int" | grep -q "NON-VOID"; then
    echo "FAIL: int should NOT go to VOID branch"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

echo "PASS: Comparison condition in for loop"

# Test 2: Multiple types with void check
echo "Test 2: Multiple types with void check"
export RETURN_TYPES="void int char"
OUTPUT2=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>/dev/null)

# Count VOID branches - should be exactly 1 (for void)
# Count only lines containing "VOID BRANCH:" followed by a type name
VOID_COUNT=$(echo "$OUTPUT2" | grep -E "^[[:space:]]*VOID BRANCH: (void|int|char)" 2>/dev/null | wc -l)
VOID_COUNT=$((VOID_COUNT + 0))
if [ "$VOID_COUNT" != "1" ]; then
    echo "FAIL: Expected exactly 1 VOID branch, got $VOID_COUNT"
    echo "Output:"
    echo "$OUTPUT2" | head -20
    exit 1
fi

# Count NON-VOID branches - should be exactly 2 (for int and char)
# Count only lines containing "NON-VOID BRANCH:" followed by a type name
NON_VOID_COUNT=$(echo "$OUTPUT2" | grep -E "^[[:space:]]*NON-VOID BRANCH: (void|int|char)" 2>/dev/null | wc -l)
NON_VOID_COUNT=$((NON_VOID_COUNT + 0))
if [ "$NON_VOID_COUNT" != "2" ]; then
    echo "FAIL: Expected exactly 2 NON-VOID branches, got $NON_VOID_COUNT"
    echo "Output:"
    echo "$OUTPUT2" | head -20
    exit 1
fi

echo "PASS: Multiple types with void check"

# Test 3: Real-world scenario - return_type_macros.h.tpl pattern
echo "Test 3: Real-world scenario - return_type_macros pattern"
TEST_TEMPLATE3="${TEST_DIR}/fixtures/test_return_type_pattern.tpl"
cat > "$TEST_TEMPLATE3" << 'EOF'
{{#for type in RETURN_TYPES}}
    {{#set macro_name={{type|sanitize_name}}}}
    {{#if macro_name}}
        // Specialized macro for return type: {{type}}
        {{#if type == 'void'}}
            #define _DAP_MOCK_WRAPPER_CUSTOM_SELECT_{{macro_name}}(func_name, return_type_full, ...) \
                _DAP_MOCK_WRAPPER_CUSTOM_VOID(func_name, __VA_ARGS__)
        {{else}}
            #define _DAP_MOCK_WRAPPER_CUSTOM_SELECT_{{macro_name}}(func_name, return_type_full, ...) \
                _DAP_MOCK_WRAPPER_CUSTOM_NONVOID(return_type_full, func_name, ##__VA_ARGS__)
        {{/if}}
    {{/if}}
{{/for}}
EOF

export RETURN_TYPES="void int"
OUTPUT3=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TEST_TEMPLATE3" 2>/dev/null)

# Check that void macro calls VOID version (macros can span multiple lines with \)
if ! echo "$OUTPUT3" | grep -A2 "_DAP_MOCK_WRAPPER_CUSTOM_SELECT_void" | grep -q "_DAP_MOCK_WRAPPER_CUSTOM_VOID"; then
    echo "FAIL: void macro should call VOID version"
    echo "Output:"
    echo "$OUTPUT3" | head -30
    exit 1
fi

# Check that int macro calls NONVOID version (macros can span multiple lines with \)
if ! echo "$OUTPUT3" | grep -A2 "_DAP_MOCK_WRAPPER_CUSTOM_SELECT_int" | grep -q "_DAP_MOCK_WRAPPER_CUSTOM_NONVOID"; then
    echo "FAIL: int macro should call NONVOID version"
    echo "Output:"
    echo "$OUTPUT3" | head -30
    exit 1
fi

# Check that void macro does NOT call NONVOID version
if echo "$OUTPUT3" | grep -A2 "_DAP_MOCK_WRAPPER_CUSTOM_SELECT_void" | grep -q "_DAP_MOCK_WRAPPER_CUSTOM_NONVOID"; then
    echo "FAIL: void macro should NOT call NONVOID version"
    echo "Output:"
    echo "$OUTPUT3" | head -30
    exit 1
fi

# Check that int macro does NOT call VOID version
if echo "$OUTPUT3" | grep -A2 "_DAP_MOCK_WRAPPER_CUSTOM_SELECT_int" | grep -q "_DAP_MOCK_WRAPPER_CUSTOM_VOID"; then
    echo "FAIL: int macro should NOT call VOID version"
    echo "Output:"
    echo "$OUTPUT3" | head -30
    exit 1
fi

echo "PASS: Real-world scenario - return_type_macros pattern"

echo ""
echo "=========================================="
echo "ALL TESTS PASSED"
echo "=========================================="

