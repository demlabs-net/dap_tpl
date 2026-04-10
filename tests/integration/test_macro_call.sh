#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Integration test for {{#macro NAME}}...{{/macro}} and {{#call NAME|args}}
# Verifies macro definition, storage, call with arguments, and
# nested template constructs within macros.

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

run_tpl() {
    local tpl_file="$1"
    cd "$DAP_TPL_DIR" && "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$tpl_file" 2>/dev/null
}

# --- Test 1: Basic macro definition and call ---
echo "Test 1: Basic macro definition and call"
TPL="/tmp/test_macro_basic_$$.tpl"
cat > "$TPL" << 'EOF'
{{#macro GREET}}
Hello, {{ARG0}}!
{{/macro}}
{{#call GREET|World}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "Hello, World!"; then
    pass "Basic macro call with argument"
else
    fail "Basic macro call" "Expected 'Hello, World!' in: $(echo "$OUTPUT" | tr '\n' ' ')"
fi

# --- Test 2: Macro with multiple arguments ---
echo "Test 2: Macro with multiple arguments"
TPL="/tmp/test_macro_multi_$$.tpl"
cat > "$TPL" << 'EOF'
{{#macro FUNC_DECL}}
{{ARG0}} {{ARG1}}({{ARG2}});
{{/macro}}
{{#call FUNC_DECL|void|my_func|int a, int b}}
{{#call FUNC_DECL|int|another_func|void}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "void my_func(int a, int b);"; then
    pass "Multi-arg macro: first call"
else
    fail "Multi-arg macro: first call" "Output: $(echo "$OUTPUT" | tr '\n' ' ')"
fi

if echo "$OUTPUT" | grep -q "int another_func(void);"; then
    pass "Multi-arg macro: second call"
else
    fail "Multi-arg macro: second call" "Output: $(echo "$OUTPUT" | tr '\n' ' ')"
fi

# --- Test 3: Macro called multiple times ---
echo "Test 3: Macro called multiple times"
TPL="/tmp/test_macro_repeat_$$.tpl"
cat > "$TPL" << 'EOF'
{{#macro GUARD}}
#ifndef {{ARG0}}_H
#define {{ARG0}}_H
{{/macro}}
{{#call GUARD|MODULE_A}}
{{#call GUARD|MODULE_B}}
{{#call GUARD|MODULE_C}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

for mod in MODULE_A MODULE_B MODULE_C; do
    if echo "$OUTPUT" | grep -q "#ifndef ${mod}_H"; then
        pass "Repeated macro call: $mod"
    else
        fail "Repeated macro call: $mod" "#ifndef ${mod}_H not found"
    fi
done

# --- Test 4: Macro definition produces no output ---
echo "Test 4: Macro definition produces no output"
TPL="/tmp/test_macro_silent_$$.tpl"
cat > "$TPL" << 'EOF'
BEFORE
{{#macro HIDDEN}}
This should not appear during definition
{{/macro}}
AFTER
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q "BEFORE" && echo "$OUTPUT" | grep -q "AFTER"; then
    pass "Macro definition: surrounding content present"
else
    fail "Macro definition: surrounding content" "Output: $OUTPUT"
fi

if echo "$OUTPUT" | grep -q "should not appear during definition"; then
    fail "Macro definition: body leaked" "Body should not appear at definition site"
else
    pass "Macro definition: body not leaked"
fi

# --- Test 5: Macro with conditional inside ---
echo "Test 5: Macro with conditional"
export ENABLE_DEBUG="1"
TPL="/tmp/test_macro_cond_$$.tpl"
cat > "$TPL" << 'EOF'
{{#macro WRAPPER}}
void {{ARG0}}(void) {
{{#if ENABLE_DEBUG}}
    debug_log("{{ARG0}} called");
{{/if}}
}
{{/macro}}
{{#call WRAPPER|my_function}}
EOF

OUTPUT=$(run_tpl "$TPL")
rm -f "$TPL"

if echo "$OUTPUT" | grep -q 'void my_function(void)'; then
    pass "Macro with conditional: function declaration"
else
    fail "Macro with conditional: function declaration" "Output: $(echo "$OUTPUT" | head -3)"
fi

if echo "$OUTPUT" | grep -q 'debug_log("my_function called")'; then
    pass "Macro with conditional: debug branch active"
else
    fail "Macro with conditional: debug branch" "Debug line not found"
fi

# --- Summary ---
echo ""
echo "=========================================="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "Macro/call tests: $PASS_COUNT/$TOTAL passed"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "FAILURES: $FAIL_COUNT"
    exit 1
fi
echo "ALL MACRO/CALL TESTS PASSED"
echo "=========================================="
