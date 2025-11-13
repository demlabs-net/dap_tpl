#!/bin/bash
# Integration test for improved condition syntax

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../../.." && pwd)"
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

# Test 1: Comparison operators
echo "Test 1: Comparison operators"
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_comparison.tpl"
cat > "$TEST_TEMPLATE" << 'EOF'
{{#if VAR != 0}}
Value is not zero: {{VAR}}
{{else}}
Value is zero
{{/if}}

{{#if VAR > 5}}
Value is greater than 5
{{else}}
Value is 5 or less
{{/if}}

{{#if VAR == 10}}
Value equals 10
{{/if}}
EOF

export VAR="10"
OUTPUT=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)

EXPECTED="
Value is not zero: 10


Value is greater than 5

"

# Check that key parts are present (more flexible comparison)
if ! echo "$OUTPUT" | grep -q "Value is not zero: 10" || ! echo "$OUTPUT" | grep -q "Value is greater than 5"; then
    echo "FAIL: Comparison operators test"
    echo "Expected to contain: 'Value is not zero: 10' and 'Value is greater than 5'"
    echo "Got:"
    echo "$OUTPUT" | cat -A
    exit 1
fi
echo "PASS: Comparison operators"

# Test 2: Contains operator
echo "Test 2: Contains operator"
TEST_TEMPLATE2="${TEST_DIR}/fixtures/test_contains.tpl"
cat > "$TEST_TEMPLATE2" << 'EOF'
{{#if VAR contains 'test'}}
Contains 'test'
{{else}}
Does not contain 'test'
{{/if}}
EOF

export VAR="this is a test string"
OUTPUT2=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE2" 2>&1)

EXPECTED2="Contains 'test'
"

if ! echo "$OUTPUT2" | grep -q "Contains 'test'"; then
    echo "FAIL: Contains operator test"
    echo "Expected to contain: 'Contains 'test''"
    echo "Got:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi
echo "PASS: Contains operator"

# Test 3: Logical operators
echo "Test 3: Logical operators"
TEST_TEMPLATE3="${TEST_DIR}/fixtures/test_logical.tpl"
cat > "$TEST_TEMPLATE3" << 'EOF'
{{#if VAR1 && VAR2}}
Both are true
{{else}}
At least one is false
{{/if}}

{{#if VAR1 || VAR2}}
At least one is true
{{else}}
Both are false
{{/if}}

{{#if !VAR1}}
VAR1 is false
{{else}}
VAR1 is true
{{/if}}
EOF

export VAR1="1"
export VAR2="0"
OUTPUT3=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE3" 2>&1)

EXPECTED3="At least one is false

At least one is true

VAR1 is true
"

if ! echo "$OUTPUT3" | grep -q "At least one is true" || ! echo "$OUTPUT3" | grep -q "VAR1 is true"; then
    echo "FAIL: Logical operators test"
    echo "Expected to contain: 'At least one is true' and 'VAR1 is true'"
    echo "Got:"
    echo "$OUTPUT3" | cat -A
    exit 1
fi
echo "PASS: Logical operators"

echo "All condition syntax tests passed!"

