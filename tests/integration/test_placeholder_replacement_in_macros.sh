#!/bin/bash
# Integration test: placeholder replacement in macro definitions
# Tests that placeholders are correctly replaced inside macro definitions
# even when constructs are present

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
FIXTURES_DIR="${TEST_DIR}/../fixtures"

# Source dap_tpl.sh
source "${DAP_TPL_DIR}/dap_tpl.sh"

# Set SCRIPTS_DIR and TEMPLATES_DIR
export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR="$(cd "${DAP_TPL_DIR}/.." && pwd)/templates"

# Create test template that reproduces the issue
test_template=$(mktemp)
cat > "$test_template" << 'EOF'
// Test template for placeholder replacement in macros
#ifndef TEST_MACROS_H
#define TEST_MACROS_H

// Test case 1: Simple placeholder in macro definition
#define TEST_MACRO_1({{PARAM_LIST}}) {{PARAM_LIST}}

// Test case 2: Placeholder in macro with construct
{{#if HAS_SEQUENCE}}
#define TEST_MACRO_2({{PARAM_LIST}}, N, ...) N
#define TEST_MACRO_3(...) TEST_MACRO_2(__VA_ARGS__{{SEQUENCE}})
{{else}}
#define TEST_MACRO_2(N, ...) N
#define TEST_MACRO_3(...) TEST_MACRO_2(__VA_ARGS__, 0)
{{/if}}

// Test case 3: Placeholder in comment
// Supporting up to {{MAX_COUNT}} arguments

#endif // TEST_MACROS_H
EOF

# Create output file
test_output=$(mktemp)

# Test with parameters
export PARAM_LIST="_1, _2"
export SEQUENCE=", 2, 1, 0"
export HAS_SEQUENCE="1"
export MAX_COUNT="22"

replace_template_placeholders "$test_template" "$test_output" \
    "PARAM_LIST=$PARAM_LIST" \
    "SEQUENCE=$SEQUENCE" \
    "HAS_SEQUENCE=$HAS_SEQUENCE" \
    "MAX_COUNT=$MAX_COUNT"

# Verify output - check that placeholders are correctly replaced
echo "=== Generated output ==="
cat "$test_output"
echo "========================"

# Test case 1: Simple placeholder should be replaced correctly
if ! grep -q "#define TEST_MACRO_1(_1, _2) _1, _2" "$test_output"; then
    echo "FAIL: TEST_MACRO_1 placeholder not replaced correctly"
    echo "Expected: #define TEST_MACRO_1(_1, _2) _1, _2"
    echo "Got:"
    grep "TEST_MACRO_1" "$test_output" || echo "  (not found)"
    exit 1
fi

# Test case 2: Placeholder in macro with construct should be replaced correctly
if ! grep -q "#define TEST_MACRO_2(_1, _2, N, ...) N" "$test_output"; then
    echo "FAIL: TEST_MACRO_2 placeholder not replaced correctly"
    echo "Expected: #define TEST_MACRO_2(_1, _2, N, ...) N"
    echo "Got:"
    grep "TEST_MACRO_2" "$test_output" || echo "  (not found)"
    exit 1
fi

# Test case 3: Check that placeholder is not prepended before #define
if grep -q "^_1, _2.*#define TEST_MACRO" "$test_output"; then
    echo "FAIL: Placeholder value prepended before #define"
    echo "Found line:"
    grep "^_1, _2.*#define TEST_MACRO" "$test_output"
    exit 1
fi

# Test case 4: Comment placeholder should be replaced correctly
if ! grep -q "// Supporting up to 22 arguments" "$test_output"; then
    echo "FAIL: Comment placeholder not replaced correctly"
    echo "Expected: // Supporting up to 22 arguments"
    echo "Got:"
    grep "Supporting up to" "$test_output" || echo "  (not found)"
    exit 1
fi

# Test case 5: Check that MAX_COUNT is not prepended before comment
if grep -q "^22//" "$test_output"; then
    echo "FAIL: MAX_COUNT value prepended before comment"
    echo "Found line:"
    grep "^22//" "$test_output"
    exit 1
fi

# Cleanup
rm -f "$test_template" "$test_output"

echo "PASS: Placeholder replacement in macros test"

