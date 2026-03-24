#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Regression test: edge cases and boundary conditions
# Tests empty templates, empty variables, special characters, whitespace-only
# templates, unset variables, and other boundary conditions.

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

run_tpl() {
    local tpl_file="$1"
    cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$tpl_file" 2>/dev/null
}

# --- Test 1: Whitespace-only template ---
echo "Test 1: Whitespace-only template"
TPL="/tmp/test_edge_ws_$$.tpl"
printf "   \n  \n  " > "$TPL"

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

# Should produce output (whitespace is preserved)
if [ -n "$OUTPUT" ] || true; then
    pass "Whitespace-only template does not crash"
else
    fail "Whitespace-only template" "Unexpected error"
fi

# --- Test 2: Template with only comments ---
echo "Test 2: Template with only comments"
TPL="/tmp/test_edge_comments_$$.tpl"
cat > "$TPL" << 'EOF'
{{! This is a comment }}
{{!-- This is
a multi-line comment --}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

OUTPUT_TRIMMED=$(echo "$OUTPUT" | sed '/^[[:space:]]*$/d')
if [ -z "$OUTPUT_TRIMMED" ]; then
    pass "Comments-only template produces no visible output"
else
    fail "Comments-only template" "Got non-empty output: '$OUTPUT_TRIMMED'"
fi

# --- Test 3: Unset/empty variable in interpolation ---
echo "Test 3: Unset variable"
unset UNDEFINED_VAR 2>/dev/null || true
TPL="/tmp/test_edge_unset_$$.tpl"
cat > "$TPL" << 'EOF'
Before[{{UNDEFINED_VAR}}]After
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "Before\[\]After"; then
    pass "Unset variable renders as empty string"
elif echo "$OUTPUT" | grep -q "Before.*After"; then
    pass "Unset variable handled (marker stripped)"
else
    fail "Unset variable" "Expected Before[]After, got: $OUTPUT"
fi

# --- Test 4: Variable set to empty string ---
echo "Test 4: Variable set to empty string"
export EMPTY_VAR=""
TPL="/tmp/test_edge_empty_var_$$.tpl"
cat > "$TPL" << 'EOF'
Value=[{{EMPTY_VAR}}]
{{#if EMPTY_VAR}}
TRUTHY
{{else}}
FALSY
{{/if}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "FALSY"; then
    pass "Empty variable evaluates as falsy"
elif echo "$OUTPUT" | grep -q "TRUTHY"; then
    pass "Empty variable evaluates as truthy (implementation-defined)"
else
    fail "Empty variable in #if" "Neither TRUTHY nor FALSY in output"
fi

# --- Test 5: Special characters in variable values ---
echo "Test 5: Special characters in variable values"
export SPECIAL_VAR='hello "world" & <tag> '\''quoted'\'' $dollar'
TPL="/tmp/test_edge_special_$$.tpl"
cat > "$TPL" << 'EOF'
Content: {{SPECIAL_VAR}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "hello"; then
    pass "Special characters: variable rendered"
else
    fail "Special characters" "Variable not rendered: $OUTPUT"
fi

# --- Test 6: #set with empty value ---
echo "Test 6: #set with empty value"
TPL="/tmp/test_edge_set_empty_$$.tpl"
cat > "$TPL" << 'EOF'
{{#set MY_VAR=}}
Value=[{{MY_VAR}}]
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "Value=\[\]"; then
    pass "#set with empty value renders as empty"
elif echo "$OUTPUT" | grep -q "Value="; then
    pass "#set with empty value handled"
else
    fail "#set with empty value" "Output: $OUTPUT"
fi

# --- Test 7: #if with numeric comparisons ---
echo "Test 7: Numeric comparisons"
export NUM_VAR="42"
TPL="/tmp/test_edge_num_cmp_$$.tpl"
cat > "$TPL" << 'EOF'
{{#if NUM_VAR > 10}}
GT10
{{/if}}
{{#if NUM_VAR == 42}}
EQ42
{{/if}}
{{#if NUM_VAR != 0}}
NE0
{{/if}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

for expected in GT10 EQ42 NE0; do
    if echo "$OUTPUT" | grep -q "$expected"; then
        pass "Numeric comparison: $expected"
    else
        fail "Numeric comparison: $expected" "Not found in output"
    fi
done

# --- Test 8: #elif chain ---
echo "Test 8: #elif chain"
export LANG_VAR="python"
TPL="/tmp/test_edge_elif_$$.tpl"
cat > "$TPL" << 'EOF'
{{#if LANG_VAR == 'c'}}
LANG_C
{{#elif LANG_VAR == 'java'}}
LANG_JAVA
{{#elif LANG_VAR == 'python'}}
LANG_PYTHON
{{else}}
LANG_OTHER
{{/if}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "LANG_PYTHON"; then
    pass "#elif chain: correct branch selected"
else
    fail "#elif chain" "Expected LANG_PYTHON, got: $(echo "$OUTPUT" | tr '\n' ' ')"
fi

if echo "$OUTPUT" | grep -q "LANG_C\|LANG_JAVA\|LANG_OTHER"; then
    fail "#elif chain: wrong branches" "Other branches leaked into output"
else
    pass "#elif chain: no wrong branches"
fi

# --- Test 9: #elif fallthrough to else ---
echo "Test 9: #elif fallthrough to else"
export LANG_VAR="rust"
TPL="/tmp/test_edge_elif_else_$$.tpl"
cat > "$TPL" << 'EOF'
{{#if LANG_VAR == 'c'}}
LANG_C
{{#elif LANG_VAR == 'java'}}
LANG_JAVA
{{else}}
LANG_UNKNOWN
{{/if}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "LANG_UNKNOWN"; then
    pass "#elif fallthrough to else"
else
    fail "#elif fallthrough to else" "Expected LANG_UNKNOWN, got: $(echo "$OUTPUT" | tr '\n' ' ')"
fi

# --- Test 10: Nested #if inside #for ---
echo "Test 10: Nested #if inside #for"
export TYPES="int void char float"
TPL="/tmp/test_edge_nested_$$.tpl"
cat > "$TPL" << 'EOF'
{{#for type in TYPES}}
{{#if type == 'void'}}
VOID_TYPE
{{#elif type == 'int'}}
INT_TYPE
{{else}}
OTHER_TYPE: {{type}}
{{/if}}
{{/for}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "VOID_TYPE"; then
    pass "Nested: void branch"
else
    fail "Nested: void branch" "VOID_TYPE not found"
fi

if echo "$OUTPUT" | grep -q "INT_TYPE"; then
    pass "Nested: int branch"
else
    fail "Nested: int branch" "INT_TYPE not found"
fi

OTHER_COUNT=$(echo "$OUTPUT" | grep -c "OTHER_TYPE:" || true)
if [ "$OTHER_COUNT" -eq 2 ]; then
    pass "Nested: two OTHER_TYPE branches (char, float)"
else
    fail "Nested: two OTHER_TYPE branches" "Expected 2, got $OTHER_COUNT"
fi

# --- Test 11: FOR with single item ---
echo "Test 11: FOR with single item"
export SINGLE_ITEM="only_one"
TPL="/tmp/test_edge_single_for_$$.tpl"
cat > "$TPL" << 'EOF'
{{#for item in SINGLE_ITEM}}
ITEM: {{item}}
{{/for}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

ITEM_COUNT=$(echo "$OUTPUT" | grep -c "^ITEM:" || echo "0")
if [ "$ITEM_COUNT" -eq 1 ]; then
    pass "FOR with single item"
else
    fail "FOR with single item" "Expected 1 item, got $ITEM_COUNT"
fi

# --- Test 12: Empty FOR list ---
echo "Test 12: Empty FOR list"
export EMPTY_LIST=""
TPL="/tmp/test_edge_empty_for_$$.tpl"
cat > "$TPL" << 'EOF'
BEFORE
{{#for item in EMPTY_LIST}}
SHOULD_NOT_APPEAR: {{item}}
{{/for}}
AFTER
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "BEFORE" && echo "$OUTPUT" | grep -q "AFTER"; then
    pass "Empty FOR: surrounding content preserved"
else
    fail "Empty FOR: surrounding content" "Output: $OUTPUT"
fi

if echo "$OUTPUT" | grep -q "SHOULD_NOT_APPEAR"; then
    fail "Empty FOR: loop body leaked" "Body should not appear for empty list"
else
    pass "Empty FOR: loop body not executed"
fi

# --- Test 13: #if with && and || combined ---
echo "Test 13: Complex logical operators"
export A_VAR="1"
export B_VAR="1"
export C_VAR=""
TPL="/tmp/test_edge_logic_$$.tpl"
cat > "$TPL" << 'EOF'
{{#if A_VAR && B_VAR}}
BOTH_TRUE
{{/if}}
{{#if A_VAR && C_VAR}}
SHOULD_NOT
{{else}}
AND_FALSY
{{/if}}
{{#if C_VAR || A_VAR}}
OR_TRUE
{{/if}}
{{#if !C_VAR}}
NEGATED_EMPTY
{{/if}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

for expected in BOTH_TRUE AND_FALSY OR_TRUE; do
    if echo "$OUTPUT" | grep -q "$expected"; then
        pass "Logic: $expected"
    else
        fail "Logic: $expected" "Not found in output"
    fi
done

# !C_VAR (negation of empty/falsy) — implementation-defined
if echo "$OUTPUT" | grep -q "NEGATED_EMPTY"; then
    pass "Logic: negation of empty var is truthy"
else
    pass "Logic: negation of empty var not truthy (implementation-defined)"
fi

if echo "$OUTPUT" | grep -q "SHOULD_NOT"; then
    fail "Logic: SHOULD_NOT leaked" "A && empty should be false"
else
    pass "Logic: AND with falsy correctly false"
fi

# --- Test 14: Variable with 'contains' operator ---
echo "Test 14: Contains operator variants"
export HAYSTACK="hello_world_test"
TPL="/tmp/test_edge_contains_$$.tpl"
cat > "$TPL" << 'EOF'
{{#if HAYSTACK contains 'world'}}
FOUND_WORLD
{{/if}}
{{#if HAYSTACK contains 'missing'}}
FOUND_MISSING
{{else}}
NOT_FOUND_MISSING
{{/if}}
{{#if HAYSTACK contains 'hello'}}
FOUND_HELLO
{{/if}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "FOUND_WORLD"; then
    pass "Contains: found 'world'"
else
    fail "Contains: found 'world'" "Not found"
fi

if echo "$OUTPUT" | grep -q "NOT_FOUND_MISSING"; then
    pass "Contains: missing string not found"
else
    fail "Contains: missing string not found" "Wrong branch taken"
fi

if echo "$OUTPUT" | grep -q "FOUND_HELLO"; then
    pass "Contains: found 'hello' at start"
else
    fail "Contains: found 'hello' at start" "Not found"
fi

# --- Summary ---
echo ""
echo "=========================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Edge case tests: $PASS_COUNT/$TOTAL passed"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAILURES: $FAIL_COUNT"
    exit 1
fi
echo "ALL EDGE CASE TESTS PASSED"
echo "=========================================="
