#!/bin/bash

AWK_CMD="${AWK_CMD:-awk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
FIXTURES_DIR="${TEST_DIR}/fixtures"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR="${FIXTURES_DIR}"
export AWKPATH="${DAP_TPL_DIR}"

ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
    echo "ERROR: Failed to build engine"
    echo "$ENGINE_OUTPUT"
    exit 1
fi
export DAP_TPL_ENGINE_PATH="$COMPILED_ENGINE"

TESTS_PASSED=0
TESTS_FAILED=0

run_tpl() {
    local tpl="$1"
    cd "$DAP_TPL_DIR" && DEBUG_ENABLED=0 "$AWK_CMD" $AWK_EXTRA_ARGS -f "$COMPILED_ENGINE" "$tpl" 2>/dev/null
}

normalize() {
    printf '%s' "$1" | tr -d '\r' | sed 's/[ \t]*$//' | \
        awk 'NF{print}' | \
        sed -e :a -e '/^\n*$/{$d;N;ba;}'
}

test_case() {
    local name="$1"
    local tpl="$2"
    local expected="$3"

    echo -n "  $name: "
    local actual
    actual=$(run_tpl "$tpl")
    actual=$(normalize "$actual")
    expected=$(normalize "$expected")

    if [ "$actual" = "$expected" ]; then
        echo "PASS"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "FAIL"
        echo "    Expected: $(echo "$expected" | head -3)"
        echo "    Actual:   $(echo "$actual" | head -3)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=== math / at / resolve / block-set tests ==="

test_case "math + at basics" \
    "${FIXTURES_DIR}/test_math_at_resolve.tpl" \
    "math: 13
at_literal: cc
at_var: dd
at_expr: bb
math_mod: 4"

test_case "resolve with prefix" \
    "${FIXTURES_DIR}/test_resolve.tpl" \
    "resolved: beta"

test_case "block-set captures value" \
    "${FIXTURES_DIR}/test_block_set.tpl" \
    "captured: 30"

test_case "block-set inside for loop" \
    "${FIXTURES_DIR}/test_block_set_loop.tpl" \
    "[0]=aa
[1]=bb
[2]=cc
[3]=dd
[4]=ee"

test_case "resolve inside for loop" \
    "${FIXTURES_DIR}/test_resolve_in_loop.tpl" \
    "0: first
1: second
2: third"

echo ""
if [ $TESTS_FAILED -eq 0 ]; then
    echo "All $TESTS_PASSED tests passed!"
    exit 0
else
    echo "$TESTS_FAILED test(s) failed, $TESTS_PASSED test(s) passed"
    exit 1
fi
