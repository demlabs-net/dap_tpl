#!/bin/bash
# Integration tests for {{#set}} construct
# Tests that {{#set}} directives don't render in output and work correctly in various contexts

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
TEMPLATES_DIR="${TEST_DIR}/fixtures"
FIXTURES_DIR="${TEST_DIR}/fixtures"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR
export AWKPATH="${DAP_TPL_DIR}"

# Build engine once at start
ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
    echo "ERROR: Failed to build engine or find engine file"
    echo "$ENGINE_OUTPUT"
    exit 1
fi
export DAP_TPL_ENGINE_PATH="$COMPILED_ENGINE"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_set() {
    local test_name="$1"
    local template_file="$2"
    local expected_output="$3"
    local vars="$4"  # Space-separated VAR=value pairs
    
    echo "Testing: $test_name"
    
    # Export variables to ENVIRON for AWK
    local env_vars=""
    if [ -n "$vars" ]; then
        for var_pair in $vars; do
            if [[ "$var_pair" == *"="* ]]; then
                local var_name="${var_pair%%=*}"
                local var_val="${var_pair#*=}"
                export "$var_name"="$var_val"
                env_vars="${env_vars} ${var_name}=\"${var_val}\""
            fi
        done
    fi
    
    # Process template using compiled engine
    local actual_output
    actual_output=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$template_file" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "  FAIL: Template processing failed with exit code $exit_code"
        echo "  Output: $actual_output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    # Normalize output - remove trailing whitespace, normalize newlines
    # Collapse multiple consecutive newlines to single newline, trim leading/trailing newlines
    actual_output=$(printf '%s' "$actual_output" | tr -d '\r' | sed 's/[ \t]*$//' | awk 'BEGIN{prev="";first=1} {if ($0 != "" || prev != "") {if (!first && prev != "") print prev; prev=$0; first=0}} END{if (prev != "") print prev}')
    expected_output=$(printf '%s' "$expected_output" | tr -d '\r' | sed 's/[ \t]*$//' | awk 'BEGIN{prev="";first=1} {if ($0 != "" || prev != "") {if (!first && prev != "") print prev; prev=$0; first=0}} END{if (prev != "") print prev}')
    
    # Check if output matches expected
    if [ "$actual_output" = "$expected_output" ]; then
        echo "  PASS"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "  FAIL: Output mismatch"
        echo "  Expected:"
        echo "$expected_output" | sed 's/^/    /'
        echo "  Actual:"
        echo "$actual_output" | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Simple {{#set}} should not render
test_set "Simple set directive" \
    "${FIXTURES_DIR}/test_set_simple.tpl" \
    "Value: 42" \
    ""

# Test 2: {{#set}} inside {{#if}} with true condition - should set variable but not render
test_set "Set inside if (true)" \
    "${FIXTURES_DIR}/test_set_in_if_true.tpl" \
    "Value: 100" \
    "ENABLE=1"

# Test 3: {{#set}} inside {{#if}} with false condition - should not render
test_set "Set inside if (false)" \
    "${FIXTURES_DIR}/test_set_in_if_false.tpl" \
    "No output" \
    "ENABLE=0"

# Test 4: Multiple {{#set}} directives - none should render
test_set "Multiple set directives" \
    "${FIXTURES_DIR}/test_set_multiple.tpl" \
    "First: 10
Second: 20
Third: 30" \
    ""

# Test 5: {{#set}} inside {{#for}} loop - should not render
test_set "Set inside for loop" \
    "${FIXTURES_DIR}/test_set_in_for.tpl" \
    "Item1
Item2
Item3" \
    "ITEMS=1|2|3"

# Test 6: Nested {{#set}} directives - should not render
test_set "Nested set directives" \
    "${FIXTURES_DIR}/test_set_nested.tpl" \
    "Outer: 100
Inner: 200" \
    "ENABLE=1"

# Test 7: {{#set}} with complex AWK expression - should not render
test_set "Set with AWK expression" \
    "${FIXTURES_DIR}/test_set_awk.tpl" \
    "Result: 15" \
    ""

# Test 8: {{#set}} inside {{#elif}} - should not render when elif is false
test_set "Set inside elif (false)" \
    "${FIXTURES_DIR}/test_set_in_elif_false.tpl" \
    "Else branch" \
    "COND=0"

# Test 9: {{#set}} inside {{#elif}} - should not render when elif is true
test_set "Set inside elif (true)" \
    "${FIXTURES_DIR}/test_set_in_elif_true.tpl" \
    "Elif value: 50" \
    "COND=1"

# Test 10: {{#set}} inside {{#else}} - should not render
test_set "Set inside else" \
    "${FIXTURES_DIR}/test_set_in_else.tpl" \
    "Else value: 99" \
    "ENABLE=0"

# Test 11: {{#set}} with empty value - should not render
test_set "Set with empty value" \
    "${FIXTURES_DIR}/test_set_empty.tpl" \
    "Value is empty" \
    ""

# Test 12: {{#set}} followed by variable usage - should set and use
test_set "Set and use variable" \
    "${FIXTURES_DIR}/test_set_and_use.tpl" \
    "Value: 42" \
    ""

# Test 13: {{#set}} inside macro definition - should not render
test_set "Set inside macro" \
    "${FIXTURES_DIR}/test_set_in_macro.tpl" \
    "Result: 100" \
    ""

# Test 14: {{#set}} with variable reference - should not render
test_set "Set with variable reference" \
    "${FIXTURES_DIR}/test_set_with_var.tpl" \
    "Result: 100" \
    "BASE=100"

# Test 15: Edge case - {{#set}} at start of template - should not render
test_set "Set at template start" \
    "${FIXTURES_DIR}/test_set_start.tpl" \
    "Content after set" \
    ""

# Test 16: Edge case - {{#set}} at end of template - should not render
test_set "Set at template end" \
    "${FIXTURES_DIR}/test_set_end.tpl" \
    "Content before set" \
    ""

# Test 17: Edge case - {{#set}} with special characters - should not render
test_set "Set with special characters" \
    "${FIXTURES_DIR}/test_set_special.tpl" \
    "Value: test_value" \
    ""

# Test 18: Edge case - Multiple {{#set}} in same line - should not render
test_set "Multiple set in same line" \
    "${FIXTURES_DIR}/test_set_same_line.tpl" \
    "First: 1
Second: 2" \
    ""

# Summary
echo ""
echo "=========================================="
echo "Test Summary:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "  Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo "=========================================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi

