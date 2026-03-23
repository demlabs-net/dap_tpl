#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Integration test for {{#sh: ... }} construct
# Verifies inline shell code execution within templates.

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

# --- Test 1: Basic shell section ---
echo "Test 1: Basic shell section"
TPL="/tmp/test_sh_basic_$$.tpl"
cat > "$TPL" << 'TPLEOF'
BEFORE
{{SH:}}
echo "SHELL_OUTPUT_99"
{{/SH}}
AFTER
TPLEOF

OUTPUT=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL" 2>/dev/null)
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "BEFORE" && echo "$OUTPUT" | grep -q "AFTER"; then
    pass "Shell section: surrounding content preserved"
else
    fail "Shell section: surrounding content" "Output: $(echo "$OUTPUT" | head -5)"
fi

if echo "$OUTPUT" | grep -q "SHELL_OUTPUT_99"; then
    pass "Shell section: code executed"
else
    fail "Shell section: code executed" "SHELL_OUTPUT_99 not found"
fi

# --- Test 2: Shell section with loop ---
echo "Test 2: Shell section with loop"
TPL="/tmp/test_sh_loop_$$.tpl"
cat > "$TPL" << 'TPLEOF'
{{SH:}}
for i in 1 2 3; do
    echo "ITEM_$i"
done
{{/SH}}
TPLEOF

OUTPUT=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL" 2>/dev/null)
rm -f "$TPL"

ITEM_COUNT=$(echo "$OUTPUT" | grep -c "^ITEM_" || true)
if [ "$ITEM_COUNT" -eq 3 ]; then
    pass "Shell section: loop generated 3 items"
else
    fail "Shell section: loop" "Expected 3 items, got $ITEM_COUNT"
fi

# --- Summary ---
echo ""
echo "=========================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Shell section tests: $PASS_COUNT/$TOTAL passed"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAILURES: $FAIL_COUNT"
    exit 1
fi
echo "ALL SHELL SECTION TESTS PASSED"
echo "=========================================="
