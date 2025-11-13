#!/bin/bash
# Integration test for elif support

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

# Test elif chain
echo "Test: elif chain"
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_elif.tpl"
cat > "$TEST_TEMPLATE" << 'EOF'
{{#if VAR == 1}}
Value is 1
{{#elif VAR == 2}}
Value is 2
{{#elif VAR == 3}}
Value is 3
{{else}}
Value is something else: {{VAR}}
{{/if}}
EOF

# Test VAR=1
export VAR="1"
OUTPUT=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)
EXPECTED="Value is 1"

# Normalize both outputs - remove all newlines and trim
OUTPUT_NORM=$(printf '%s' "$OUTPUT" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
EXPECTED_NORM=$(printf '%s' "$EXPECTED" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ "$OUTPUT_NORM" != "$EXPECTED_NORM" ]; then
    echo "FAIL: elif test with VAR=1"
    echo "Expected: $EXPECTED"
    echo "Got: $OUTPUT"
    exit 1
fi

# Test VAR=2
export VAR="2"
OUTPUT=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)
EXPECTED="Value is 2"

# Normalize both outputs (remove trailing newlines for comparison)
OUTPUT_NORM=$(printf '%s' "$OUTPUT" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
EXPECTED_NORM=$(printf '%s' "$EXPECTED" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ "$OUTPUT_NORM" != "$EXPECTED_NORM" ]; then
    echo "FAIL: elif test with VAR=2"
    echo "Expected: $EXPECTED"
    echo "Got: $OUTPUT"
    exit 1
fi

# Test VAR=3
export VAR="3"
OUTPUT=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)
EXPECTED="Value is 3"

# Normalize both outputs (remove trailing newlines for comparison)
OUTPUT_NORM=$(printf '%s' "$OUTPUT" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
EXPECTED_NORM=$(printf '%s' "$EXPECTED" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ "$OUTPUT_NORM" != "$EXPECTED_NORM" ]; then
    echo "FAIL: elif test with VAR=3"
    echo "Expected: $EXPECTED"
    echo "Got: $OUTPUT"
    exit 1
fi

# Test VAR=5 (else branch)
export VAR="5"
OUTPUT=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)
EXPECTED="Value is something else: 5"

# Normalize both outputs (remove trailing newlines for comparison)
OUTPUT_NORM=$(printf '%s' "$OUTPUT" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
EXPECTED_NORM=$(printf '%s' "$EXPECTED" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ "$OUTPUT_NORM" != "$EXPECTED_NORM" ]; then
    echo "FAIL: elif test with VAR=5 (else branch)"
    echo "Expected: $EXPECTED"
    echo "Got: $OUTPUT"
    exit 1
fi

echo "PASS: elif chain tests"

