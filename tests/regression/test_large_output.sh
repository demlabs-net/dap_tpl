#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Regression test: large template output (>8KB)
# Verifies that mawk's sprintf buffer limit (8192 bytes) does not truncate
# output, thanks to AWK_EXTRA_ARGS="-W sprintf=131072" and the streaming
# renderer / chunked include machinery.

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
export DAP_TPL_ENGINE_PATH="$COMPILED_ENGINE"

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

# --- Test 1: FOR loop generating >8KB output ---
echo "Test 1: FOR loop generating >8KB output"

# 200 items * ~50 chars each ≈ 10KB
ITEMS=""
for i in $(seq 1 200); do
    [ -n "$ITEMS" ] && ITEMS="${ITEMS} "
    ITEMS="${ITEMS}item_${i}"
done
export ITEMS

TPL="/tmp/test_large_for_$$.tpl"
cat > "$TPL" << 'EOF'
{{#for item in ITEMS}}
// Generated entry: {{item}} with padding_text_to_make_line_longer
{{/for}}
EOF

OUTPUT=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL" 2>/dev/null)
rm -f "$TPL"

LINE_COUNT=$(echo "$OUTPUT" | grep -c "^// Generated entry: item_" || echo "0")
if [ "$LINE_COUNT" -eq 200 ]; then
    pass "FOR loop generating >8KB output ($LINE_COUNT lines)"
else
    fail "FOR loop generating >8KB output" "Expected 200 lines, got $LINE_COUNT"
fi

OUTPUT_SIZE=$(echo "$OUTPUT" | wc -c)
if [ "$OUTPUT_SIZE" -gt 8192 ]; then
    pass "Output size exceeds 8KB (${OUTPUT_SIZE} bytes)"
else
    fail "Output size exceeds 8KB" "Only ${OUTPUT_SIZE} bytes"
fi

if echo "$OUTPUT" | grep -q "^// Generated entry: item_1 "; then
    pass "First item present"
else
    fail "First item present" "item_1 not found"
fi

if echo "$OUTPUT" | grep -q "^// Generated entry: item_200 "; then
    pass "Last item present"
else
    fail "Last item present" "item_200 not found"
fi

# --- Test 2: Deeply nested FOR loops ---
echo "Test 2: Deeply nested FOR loops"

export OUTER="A B C"
export MIDDLE="x y"
export INNER="1 2 3"

TPL2="/tmp/test_nested_for_$$.tpl"
cat > "$TPL2" << 'EOF'
{{#for o in OUTER}}
{{#for m in MIDDLE}}
{{#for i in INNER}}
[{{o}}.{{m}}.{{i}}]
{{/for}}
{{/for}}
{{/for}}
EOF

OUTPUT2=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL2" 2>/dev/null)
rm -f "$TPL2"

COMBO_COUNT=$(echo "$OUTPUT2" | grep -c '^\[.\..\..\]$' || echo "0")
if [ "$COMBO_COUNT" -eq 18 ]; then
    pass "Deeply nested FOR (3 levels, 18 combinations)"
else
    fail "Deeply nested FOR" "Expected 18 combos, got $COMBO_COUNT"
fi

for expected in "[A.x.1]" "[A.y.3]" "[B.x.2]" "[C.y.3]"; do
    if echo "$OUTPUT2" | grep -qF "$expected"; then
        pass "Nested FOR contains $expected"
    else
        fail "Nested FOR contains $expected" "Not found in output"
    fi
done

# --- Test 3: Large included file (>40 lines, triggers chunking) ---
echo "Test 3: Large included file (>40 lines, chunked)"

LARGE_FILE="${TEMPLATES_DIR}/large_data.h"
: > "$LARGE_FILE"
for i in $(seq 1 100); do
    echo "#define CONSTANT_${i} ${i}  /* padding to make line longer and trigger buffer */" >> "$LARGE_FILE"
done

TPL3="/tmp/test_large_include_$$.tpl"
cat > "$TPL3" << 'EOF'
// Header
{{#include large_data.h}}
// Footer
EOF

OUTPUT3=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL3" 2>/dev/null)
rm -f "$TPL3" "$LARGE_FILE"

if echo "$OUTPUT3" | grep -q "^// Header"; then
    pass "Large include: header present"
else
    fail "Large include: header present" "Header not found"
fi

if echo "$OUTPUT3" | grep -q "^// Footer"; then
    pass "Large include: footer present"
else
    fail "Large include: footer present" "Footer not found"
fi

DEFINE_COUNT=$(echo "$OUTPUT3" | grep -c "^#define CONSTANT_" || echo "0")
if [ "$DEFINE_COUNT" -eq 100 ]; then
    pass "Large include: all 100 lines present"
else
    fail "Large include: all 100 lines present" "Got $DEFINE_COUNT lines"
fi

if echo "$OUTPUT3" | grep -q "#define CONSTANT_1 "; then
    pass "Large include: first line intact"
else
    fail "Large include: first line intact" "CONSTANT_1 not found"
fi

if echo "$OUTPUT3" | grep -q "#define CONSTANT_100 "; then
    pass "Large include: last line intact"
else
    fail "Large include: last line intact" "CONSTANT_100 not found"
fi

# --- Test 4: Large .tpl include (>40 lines, subprocess chunking) ---
echo "Test 4: Large .tpl include with variable substitution"

LARGE_TPL="${TEMPLATES_DIR}/large_gen.tpl"
: > "$LARGE_TPL"
for i in $(seq 1 80); do
    echo "LINE_${i}: {{PREFIX}}_value_${i}" >> "$LARGE_TPL"
done

TPL4="/tmp/test_large_tpl_include_$$.tpl"
cat > "$TPL4" << 'EOF'
// Start
{{#include large_gen.tpl}}
// End
EOF

export PREFIX="TEST"

OUTPUT4=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL4" 2>/dev/null)
rm -f "$TPL4" "$LARGE_TPL"

TPL_LINE_COUNT=$(echo "$OUTPUT4" | grep -c "^LINE_.*TEST_value_" || echo "0")
if [ "$TPL_LINE_COUNT" -eq 80 ]; then
    pass "Large .tpl include: all 80 lines with substitution"
else
    fail "Large .tpl include" "Expected 80 substituted lines, got $TPL_LINE_COUNT"
fi

if echo "$OUTPUT4" | grep -q "^LINE_1: TEST_value_1$"; then
    pass "Large .tpl include: first line correct"
else
    fail "Large .tpl include: first line correct" "LINE_1 mismatch"
fi

if echo "$OUTPUT4" | grep -q "^LINE_80: TEST_value_80$"; then
    pass "Large .tpl include: last line correct"
else
    fail "Large .tpl include: last line correct" "LINE_80 mismatch"
fi

# --- Test 5: Very large output via FOR (>64KB, stress test) ---
echo "Test 5: Very large output via FOR (>64KB)"

MANY_ITEMS=""
for i in $(seq 1 500); do
    [ -n "$MANY_ITEMS" ] && MANY_ITEMS="${MANY_ITEMS} "
    MANY_ITEMS="${MANY_ITEMS}entry_${i}"
done
export MANY_ITEMS

TPL5="/tmp/test_very_large_$$.tpl"
cat > "$TPL5" << 'EOF'
{{#for item in MANY_ITEMS}}
static void handler_{{item}}(void) { /* handler implementation padding text to reach 64KB total output size quickly */ }
{{/for}}
EOF

OUTPUT5=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$TPL5" 2>/dev/null)
rm -f "$TPL5"

HANDLER_COUNT=$(echo "$OUTPUT5" | grep -c "^static void handler_entry_" || echo "0")
if [ "$HANDLER_COUNT" -eq 500 ]; then
    pass "Very large output: all 500 handlers generated"
else
    fail "Very large output" "Expected 500 handlers, got $HANDLER_COUNT"
fi

OUTPUT5_SIZE=$(echo "$OUTPUT5" | wc -c)
if [ "$OUTPUT5_SIZE" -gt 50000 ]; then
    pass "Very large output: exceeds 50KB (${OUTPUT5_SIZE} bytes)"
else
    fail "Very large output: exceeds 50KB" "Only ${OUTPUT5_SIZE} bytes"
fi

# --- Summary ---
echo ""
echo "=========================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Large output tests: $PASS_COUNT/$TOTAL passed"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAILURES: $FAIL_COUNT"
    exit 1
fi
echo "ALL LARGE OUTPUT TESTS PASSED"
echo "=========================================="
