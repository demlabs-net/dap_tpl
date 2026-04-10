#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Integration test for comments

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

# Test single-line comments
echo "Test: Single-line comments"
TEST_TEMPLATE="${TEST_DIR}/fixtures/test_comments.tpl"
cat > "$TEST_TEMPLATE" << 'EOF'
Output line 1
{{! This is a comment }}
Output line 2
{{! Another comment with {{VAR}} inside }}
Output line 3
EOF

OUTPUT=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TEST_TEMPLATE" 2>&1)
EXPECTED="Output line 1
Output line 2
Output line 3"

# Normalize both outputs (remove trailing newlines for comparison)
OUTPUT_NORM=$(echo "$OUTPUT" | sed 's/[[:space:]]*$//')
EXPECTED_NORM=$(echo "$EXPECTED" | sed 's/[[:space:]]*$//')

if [ "$OUTPUT_NORM" != "$EXPECTED_NORM" ]; then
    echo "FAIL: Single-line comments test"
    echo "Expected:"
    echo "$EXPECTED" | cat -A
    echo "Got:"
    echo "$OUTPUT" | cat -A
    exit 1
fi
echo "PASS: Single-line comments"

# Test multi-line comments
echo "Test: Multi-line comments"
TEST_TEMPLATE2="${TEST_DIR}/fixtures/test_comments_ml.tpl"
cat > "$TEST_TEMPLATE2" << 'EOF'
Output line 1
{{!--
This is a multi-line comment
It can span multiple lines
And contain {{VAR}} markers
--}}
Output line 2
EOF

OUTPUT2=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TEST_TEMPLATE2" 2>&1)
EXPECTED2="Output line 1
Output line 2"

# Normalize both outputs (remove trailing newlines for comparison)
OUTPUT2_NORM=$(echo "$OUTPUT2" | sed 's/[[:space:]]*$//')
EXPECTED2_NORM=$(echo "$EXPECTED2" | sed 's/[[:space:]]*$//')

if [ "$OUTPUT2_NORM" != "$EXPECTED2_NORM" ]; then
    echo "FAIL: Multi-line comments test"
    echo "Expected:"
    echo "$EXPECTED2" | cat -A
    echo "Got:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi
echo "PASS: Multi-line comments"

echo "All comment tests passed!"

