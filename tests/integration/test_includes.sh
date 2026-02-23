#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-mawk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Integration test for include system with recursive template processing

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
TEMPLATES_DIR="${TEST_DIR}/fixtures"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR
export AWKPATH="${DAP_TPL_DIR}"

mkdir -p "${TEST_DIR}/fixtures"

# Create included template
INCLUDED_TEMPLATE="${TEST_DIR}/fixtures/included.tpl"
cat > "$INCLUDED_TEMPLATE" << 'EOF'
Included content: {{VAR}}
EOF

# Create main template
MAIN_TEMPLATE="${TEST_DIR}/fixtures/test_include.tpl"
cat > "$MAIN_TEMPLATE" << 'EOF'
Main content
{{#include "included.tpl"}}
More main content
EOF

# Set variable
export VAR="test_value"

# Expected output
EXPECTED="Main content
Included content: test_value
More main content
"

# Build engine and capture path
ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
    echo "ERROR: Failed to build engine or find engine file"
    echo "$ENGINE_OUTPUT"
    exit 1
fi

OUTPUT=$(cd "$DAP_TPL_DIR" && env AWKPATH="$DAP_TPL_DIR" DAP_TPL_ENGINE_PATH="$COMPILED_ENGINE" "$AWK_CMD" -f "$COMPILED_ENGINE" "$MAIN_TEMPLATE" 2>&1)

# Check for shell errors first
if echo "$OUTPUT" | grep -q "Syntax error"; then
    echo "FAIL: Shell syntax error in include processing"
    echo "Got:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Normalize both outputs (remove trailing/leading newlines for comparison)
OUTPUT_NORM=$(echo "$OUTPUT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
EXPECTED_NORM=$(echo "$EXPECTED" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ "$OUTPUT_NORM" != "$EXPECTED_NORM" ]; then
    echo "FAIL: Output mismatch"
    echo "Expected:"
    echo "$EXPECTED" | cat -A
    echo "Got:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

# Test regular file include
REGULAR_FILE="${TEST_DIR}/fixtures/config.h"
cat > "$REGULAR_FILE" << 'EOF'
#define CONFIG_VALUE 42
EOF

REGULAR_TEMPLATE="${TEST_DIR}/fixtures/test_regular_include.tpl"
cat > "$REGULAR_TEMPLATE" << 'EOF'
{{#include "config.h"}}
EOF

EXPECTED_REGULAR="#define CONFIG_VALUE 42
"

# Use the same compiled engine (don't rely on cached version)
OUTPUT_REGULAR=$(cd "$DAP_TPL_DIR" && env AWKPATH="$DAP_TPL_DIR" "$AWK_CMD" -f "$COMPILED_ENGINE" "$REGULAR_TEMPLATE" 2>&1)

# Check for shell errors
if echo "$OUTPUT_REGULAR" | grep -q "Syntax error"; then
    echo "FAIL: Shell syntax error in regular file include"
    echo "Got:"
    echo "$OUTPUT_REGULAR" | cat -A
    exit 1
fi

# Normalize both outputs
OUTPUT_REGULAR_NORM=$(echo "$OUTPUT_REGULAR" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
EXPECTED_REGULAR_NORM=$(echo "$EXPECTED_REGULAR" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ "$OUTPUT_REGULAR_NORM" != "$EXPECTED_REGULAR_NORM" ]; then
    echo "FAIL: Regular file include mismatch"
    echo "Expected:"
    echo "$EXPECTED_REGULAR" | cat -A
    echo "Got:"
    echo "$OUTPUT_REGULAR" | cat -A
    exit 1
fi

echo "PASS"
rm -f "$INCLUDED_TEMPLATE" "$MAIN_TEMPLATE" "$REGULAR_FILE" "$REGULAR_TEMPLATE"

