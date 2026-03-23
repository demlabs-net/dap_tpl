#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Integration test for {{AWK: ... }} construct
# Verifies inline AWK code execution within templates.

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
TEMPLATES_DIR="${TEST_DIR}/fixtures"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR
export AWKPATH="${DAP_TPL_DIR}"

mkdir -p "${TEMPLATES_DIR}"

ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
    echo "ERROR: Failed to build engine or find engine file"
    echo "$ENGINE_OUTPUT"
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "FAIL: $1"
    echo "  $2"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# --- Test 1: Basic AWK section ---
echo "Test 1: Basic AWK section"
TPL="/tmp/test_awk_basic_$$.tpl"
cat > "$TPL" << 'TPLEOF'
BEFORE
{{AWK:}}
BEGIN { print "AWK_OUTPUT_42" }
{{/AWK}}
AFTER
TPLEOF

OUTPUT=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL" 2>/dev/null)
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "BEFORE" && echo "$OUTPUT" | grep -q "AFTER"; then
    pass "AWK section: surrounding content preserved"
else
    fail "AWK section: surrounding content" "Output: $OUTPUT"
fi

if echo "$OUTPUT" | grep -q "AWK_OUTPUT_42"; then
    pass "AWK section: code executed"
else
    fail "AWK section: code executed" "AWK_OUTPUT_42 not found in: $OUTPUT"
fi

# --- Test 2: AWK section with computation ---
echo "Test 2: AWK section with computation"
TPL="/tmp/test_awk_compute_$$.tpl"
cat > "$TPL" << 'TPLEOF'
{{AWK:}}
BEGIN {
    for (i = 0; i < 5; i++) {
        printf "LINE_%d\n", i
    }
}
{{/AWK}}
TPLEOF

OUTPUT=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL" 2>/dev/null)
rm -f "$TPL"

LINE_COUNT=$(echo "$OUTPUT" | grep -c "^LINE_" || true)
if [ "$LINE_COUNT" -eq 5 ]; then
    pass "AWK section: loop generated 5 lines"
else
    fail "AWK section: loop generated 5 lines" "Got $LINE_COUNT lines"
fi

ALL_PRESENT=1
for i in 0 1 2 3 4; do
    if ! echo "$OUTPUT" | grep -q "LINE_$i"; then
        fail "AWK section: LINE_$i present" "Not found"
        ALL_PRESENT=0
    fi
done
if [ "$ALL_PRESENT" -eq 1 ]; then
    pass "AWK section: all loop iterations present"
fi

# --- Summary ---
echo ""
echo "=========================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "AWK section tests: $PASS_COUNT/$TOTAL passed"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAILURES: $FAIL_COUNT"
    exit 1
fi
echo "ALL AWK SECTION TESTS PASSED"
echo "=========================================="
