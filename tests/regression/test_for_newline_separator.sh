#!/bin/bash
# Regression test for for loop with |newline separator filter
# This test verifies that {{#for entry in DATA|newline}} correctly processes
# newline-separated data, fixing the bug where separator was not properly
# handled when using |newline filter in for loops.
#
# Bug: When using FUNCTIONS_DATA|newline in for loop, the separator "\n"
# was set correctly but the split logic didn't properly handle it.
# Fixed in: constructs/for/evaluator.awk

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

# Test 1: Basic newline-separated data with |newline filter
echo "Test 1: Basic newline-separated data with |newline filter"
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_for_newline_basic.tpl"
cat > "$TEST_TEMPLATE" << 'EOF'
{{#for entry in FUNCTIONS_DATA|newline}}
Entry: {{entry}}
{{/for}}
EOF

# Set FUNCTIONS_DATA as newline-separated string (simulating file content)
export FUNCTIONS_DATA="func1
func2
func3"

OUTPUT=$(cd "$DAP_TPL_DIR" && mawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>/dev/null)

# Check that all entries are processed
if ! echo "$OUTPUT" | grep -q "Entry: func1"; then
    echo "FAIL: func1 should be processed"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "Entry: func2"; then
    echo "FAIL: func2 should be processed"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "Entry: func3"; then
    echo "FAIL: func3 should be processed"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Count entries - should be exactly 3
ENTRY_COUNT=$(echo "$OUTPUT" | grep -c "^Entry:" || echo "0")
if [ "$ENTRY_COUNT" != "3" ]; then
    echo "FAIL: Expected exactly 3 entries, got $ENTRY_COUNT"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

echo "PASS: Basic newline-separated data with |newline filter"

# Test 2: Newline-separated data with pipe-separated entries (real-world scenario)
echo "Test 2: Newline-separated data with pipe-separated entries"
TEST_TEMPLATE2="${TEST_DIR}/fixtures/test_for_newline_pipe.tpl"
cat > "$TEST_TEMPLATE2" << 'EOF'
{{#for entry in FUNCTIONS_DATA|newline}}
    {{entry|split|pipe}}
    Function: {{entry|part|1}}
    Return type: {{entry|part|0}}
{{/for}}
EOF

# Set FUNCTIONS_DATA as newline-separated string with pipe-separated entries
export FUNCTIONS_DATA="void|func1
int|func2
char*|func3"

OUTPUT2=$(cd "$DAP_TPL_DIR" && mawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE2" 2>/dev/null)

# Check that all functions are processed correctly
if ! echo "$OUTPUT2" | grep -q "Function: func1"; then
    echo "FAIL: func1 should be processed"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

if ! echo "$OUTPUT2" | grep -q "Return type: void"; then
    echo "FAIL: void return type should be found for func1"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

if ! echo "$OUTPUT2" | grep -q "Function: func2"; then
    echo "FAIL: func2 should be processed"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

if ! echo "$OUTPUT2" | grep -q "Return type: int"; then
    echo "FAIL: int return type should be found for func2"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

if ! echo "$OUTPUT2" | grep -q "Function: func3"; then
    echo "FAIL: func3 should be processed"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

if ! echo "$OUTPUT2" | grep -q "Return type: char\*"; then
    echo "FAIL: char* return type should be found for func3"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

# Count function entries - should be exactly 3
FUNC_COUNT=$(echo "$OUTPUT2" | grep -c "^[[:space:]]*Function:" || echo "0")
if [ "$FUNC_COUNT" != "3" ]; then
    echo "FAIL: Expected exactly 3 function entries, got $FUNC_COUNT"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

echo "PASS: Newline-separated data with pipe-separated entries"

# Test 3: Empty newline-separated data
echo "Test 3: Empty newline-separated data"
export FUNCTIONS_DATA=""
OUTPUT3=$(cd "$DAP_TPL_DIR" && mawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>/dev/null)

# Should produce no output (empty loop)
if [ -n "$OUTPUT3" ]; then
    echo "FAIL: Empty data should produce no output"
    echo "Output:"
    echo "$OUTPUT3" | cat -A
    exit 1
fi

echo "PASS: Empty newline-separated data"

# Test 4: Single entry with newline
echo "Test 4: Single entry with newline"
export FUNCTIONS_DATA="func1"
OUTPUT4=$(cd "$DAP_TPL_DIR" && mawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>/dev/null)

# Should process single entry
if ! echo "$OUTPUT4" | grep -q "Entry: func1"; then
    echo "FAIL: Single entry should be processed"
    echo "Output:"
    echo "$OUTPUT4" | cat -A
    exit 1
fi

ENTRY_COUNT4=$(echo "$OUTPUT4" | grep -c "^Entry:" || echo "0")
if [ "$ENTRY_COUNT4" != "1" ]; then
    echo "FAIL: Expected exactly 1 entry, got $ENTRY_COUNT4"
    echo "Output:"
    echo "$OUTPUT4" | cat -A
    exit 1
fi

echo "PASS: Single entry with newline"

# Test 5: Real-world scenario - function wrappers generation pattern
echo "Test 5: Real-world scenario - function wrappers generation"
TEST_TEMPLATE5="${TEST_DIR}/fixtures/test_for_newline_wrappers.tpl"
cat > "$TEST_TEMPLATE5" << 'EOF'
{{#for entry in FUNCTIONS_DATA|newline}}
    {{entry|split|pipe}}
    {{#set return_type={{entry|part|0}}}}
    {{#set func_name={{entry|part|1}}}}
    {{#if func_name}}
        // Wrapper for function: {{func_name}}
        // Return type: {{return_type}}
        #define _DAP_MOCK_WRAPPER_CUSTOM_FOR_{{func_name}}(return_type_full, ...) \
            extern return_type_full __real_{{func_name}}(_DAP_MOCK_MAP(_DAP_MOCK_PARAM_DECL, ##__VA_ARGS__)); \
            static return_type_full __mock_impl_{{func_name}}(_DAP_MOCK_MAP(_DAP_MOCK_PARAM_DECL, ##__VA_ARGS__)); \
            return_type_full __wrap_{{func_name}}(_DAP_MOCK_MAP(_DAP_MOCK_PARAM_DECL, ##__VA_ARGS__))
    {{/if}}
{{/for}}
EOF

# Set FUNCTIONS_DATA as newline-separated string (simulating custom_mocks_list.txt format)
export FUNCTIONS_DATA="dap_client_http_t*|dap_client_http_request_full|PARAM(...)
void|dap_client_http_request_async|PARAM(...)
dap_client_http_t*|dap_client_http_request|PARAM(...)"

OUTPUT5=$(cd "$DAP_TPL_DIR" && mawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE5" 2>/dev/null)

# Check that all functions are processed
if ! echo "$OUTPUT5" | grep -q "Wrapper for function: dap_client_http_request_full"; then
    echo "FAIL: dap_client_http_request_full should be processed"
    echo "Output:"
    echo "$OUTPUT5" | head -30
    exit 1
fi

if ! echo "$OUTPUT5" | grep -q "Return type: dap_client_http_t\*"; then
    echo "FAIL: dap_client_http_t* return type should be found"
    echo "Output:"
    echo "$OUTPUT5" | head -30
    exit 1
fi

if ! echo "$OUTPUT5" | grep -q "Wrapper for function: dap_client_http_request_async"; then
    echo "FAIL: dap_client_http_request_async should be processed"
    echo "Output:"
    echo "$OUTPUT5" | head -30
    exit 1
fi

if ! echo "$OUTPUT5" | grep -q "Return type: void"; then
    echo "FAIL: void return type should be found"
    echo "Output:"
    echo "$OUTPUT5" | head -30
    exit 1
fi

if ! echo "$OUTPUT5" | grep -q "_DAP_MOCK_WRAPPER_CUSTOM_FOR_dap_client_http_request_full"; then
    echo "FAIL: Macro for dap_client_http_request_full should be generated"
    echo "Output:"
    echo "$OUTPUT5" | head -30
    exit 1
fi

if ! echo "$OUTPUT5" | grep -q "__real_dap_client_http_request_full"; then
    echo "FAIL: __real_dap_client_http_request_full should be generated"
    echo "Output:"
    echo "$OUTPUT5" | head -30
    exit 1
fi

# Count wrapper definitions - should be exactly 3
WRAPPER_COUNT=$(echo "$OUTPUT5" | grep -c "^[[:space:]]*// Wrapper for function:" || echo "0")
if [ "$WRAPPER_COUNT" != "3" ]; then
    echo "FAIL: Expected exactly 3 wrapper definitions, got $WRAPPER_COUNT"
    echo "Output:"
    echo "$OUTPUT5" | head -50
    exit 1
fi

echo "PASS: Real-world scenario - function wrappers generation"

echo ""
echo "=========================================="
echo "ALL REGRESSION TESTS PASSED"
echo "=========================================="

