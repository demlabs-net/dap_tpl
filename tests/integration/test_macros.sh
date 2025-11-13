#!/bin/bash
# Integration test for macro system

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
TEMPLATES_DIR="${TEST_DIR}/fixtures"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR
export AWKPATH="${DAP_TPL_DIR}"

# Create test template
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_macro.tpl"
mkdir -p "${TEST_DIR}/fixtures"

cat > "$TEST_TEMPLATE" << 'EOF'
{{#macro GREETING}}
Hello, {{ARG0}}! Welcome to {{ARG1}}.
{{/macro}}

{{#call GREETING|World|DAP TPL}}

{{#macro CONDITIONAL}}
{{#if ARG0}}
Value is true: {{ARG1}}
{{else}}
Value is false: {{ARG1}}
{{/if}}
{{/macro}}

{{#call CONDITIONAL|1|test}}
EOF

# Expected output
EXPECTED="Hello, World! Welcome to DAP TPL.

Value is true: test
"

# Build engine and capture path
ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
    echo "ERROR: Failed to build engine or find engine file"
    echo "$ENGINE_OUTPUT"
    exit 1
fi

OUTPUT=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)

# Normalize both outputs (remove trailing/leading newlines for comparison)
OUTPUT_NORM=$(printf '%s' "$OUTPUT" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
EXPECTED_NORM=$(printf '%s' "$EXPECTED" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ "$OUTPUT_NORM" != "$EXPECTED_NORM" ]; then
    echo "FAIL: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED" | cat -A
    echo "Got:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

echo "PASS"
rm -f "$TEST_TEMPLATE"

