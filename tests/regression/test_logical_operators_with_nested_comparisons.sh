#!/bin/bash
# Regression test for logical operators (||, &&) with nested comparisons
# This test verifies that logical operators correctly handle nested comparison
# expressions that contain the pipe character '|' in their internal structure.
#
# Bug: Delimiter conflict in parsed condition structure
# When parse_logical_or/and used '|' as delimiter, nested comparisons (which
# also use '|' internally) were incorrectly split, causing wrong evaluation.
#
# Example of the bug:
#   Condition: ARCH == "sve" || ARCH == "sve2"
#   Parser output: "OR|==|ARCH|sve|==|ARCH|sve2"  (using | delimiter)
#   After split("|"): [1]=OR [2]=== [3]=ARCH [4]=sve [5]=== [6]=ARCH [7]=sve2
#   Expected: [1]=OR [2]==|ARCH|sve [3]==|ARCH|sve2
#   Result: evaluate_logical_or received "==" as left expression (always true!)
#
# Root cause:
# 1. Logical operators (OR, AND, NOT) used '|' as delimiter
# 2. Nested comparisons ALSO use '|' internally: "==|VAR|value"
# 3. When split() is called, both delimiters are treated the same
#
# Fixed by:
# 1. Changed logical operators to use '@@' delimiter: "OR@@left@@right"
# 2. Updated evaluate_parsed_condition to detect delimiter by operator prefix
# 3. Applied same fix to AND and NOT operators
#
# This regression test ensures the bug doesn't reoccur and covers edge cases.

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
FIXTURES_DIR="${TEST_DIR}/fixtures"

# Source the main dap_tpl library
source "${DAP_TPL_DIR}/dap_tpl.sh"

export AWKPATH="${DAP_TPL_DIR}"

mkdir -p "${FIXTURES_DIR}"

echo "=========================================="
echo "Regression Test: Logical Operators with Nested Comparisons"
echo "=========================================="

PASS_COUNT=0
FAIL_COUNT=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local template_content="$2"
    local expected_output="$3"
    local var_assignments="$4"
    
    echo ""
    echo "Test: $test_name"
    
    local test_file="${FIXTURES_DIR}/test_logical_${PASS_COUNT}_${FAIL_COUNT}.tpl"
    local output_file="${FIXTURES_DIR}/test_logical_${PASS_COUNT}_${FAIL_COUNT}.out"
    
    echo "$template_content" > "$test_file"
    
    # Parse variable assignments and call replace_template_placeholders
    eval "replace_template_placeholders '$test_file' '$output_file' $var_assignments"
    
    local actual_output=$(cat "$output_file" | grep -v '^[[:space:]]*$' | head -1)
    
    if [ "$actual_output" = "$expected_output" ]; then
        echo "  ✅ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ❌ FAIL"
        echo "    Expected: '$expected_output'"
        echo "    Got:      '$actual_output'"
        echo "    Full output:"
        cat "$output_file" | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    rm -f "$test_file" "$output_file"
}

# =============================================================================
# Test Group 1: OR operator with nested comparisons (the original bug)
# =============================================================================

echo ""
echo "=== Test Group 1: OR operator with nested comparisons ==="

# Test 1.1: OR with == comparisons (should be FALSE for non-matching value)
run_test \
    "OR with == (no match)" \
    '{{#if ARCH == "sve" || ARCH == "sve2"}}MATCH{{else}}NO MATCH{{/if}}' \
    "NO MATCH" \
    'ARCH=neon'

# Test 1.2: OR with == comparisons (should be TRUE for first match)
run_test \
    "OR with == (first match)" \
    '{{#if ARCH == "sve" || ARCH == "sve2"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'ARCH=sve'

# Test 1.3: OR with == comparisons (should be TRUE for second match)
run_test \
    "OR with == (second match)" \
    '{{#if ARCH == "sve" || ARCH == "sve2"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'ARCH=sve2'

# Test 1.4: OR with != comparisons (should be TRUE when either is not equal)
run_test \
    "OR with != (true)" \
    '{{#if ARCH != "x86" || ARCH != "arm"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'ARCH=neon'

# Test 1.5: OR with != (should be TRUE when not equal)
run_test \
    "OR with != (not equal)" \
    '{{#if ARCH != "sve" || ARCH != "sve2"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'ARCH=neon'

# Note: Tests with special chars (|, @@) in values are not supported
# as they conflict with internal delimiters. This is a known limitation.

# =============================================================================
# Test Group 2: AND operator with nested comparisons
# =============================================================================

echo ""
echo "=== Test Group 2: AND operator with nested comparisons ==="

# Test 2.1: AND with == comparisons (should be FALSE when first is false)
run_test \
    "AND with == (first false)" \
    '{{#if ARCH == "neon" && TYPE == "simd"}}MATCH{{else}}NO MATCH{{/if}}' \
    "NO MATCH" \
    'ARCH=sve TYPE=simd'

# Test 2.2: AND with == comparisons (should be FALSE when second is false)
run_test \
    "AND with == (second false)" \
    '{{#if ARCH == "neon" && TYPE == "simd"}}MATCH{{else}}NO MATCH{{/if}}' \
    "NO MATCH" \
    'ARCH=neon TYPE=ref'

# Test 2.3: AND with == comparisons (should be TRUE when both are true)
run_test \
    "AND with == (both true)" \
    '{{#if ARCH == "neon" && TYPE == "simd"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'ARCH=neon TYPE=simd'

# Test 2.4: AND with != comparisons (should be TRUE when both are not equal)
run_test \
    "AND with != (both true)" \
    '{{#if ARCH != "sve" && ARCH != "sve2"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'ARCH=neon'

# Test 2.5: AND with != comparisons (should be FALSE when one is equal)
run_test \
    "AND with != (one false)" \
    '{{#if ARCH != "sve" && ARCH != "sve2"}}MATCH{{else}}NO MATCH{{/if}}' \
    "NO MATCH" \
    'ARCH=sve'

# =============================================================================
# Test Group 3: NOT operator with nested comparisons
# =============================================================================

echo ""
echo "=== Test Group 3: NOT operator with nested comparisons ==="

# Test 3.1: NOT with == comparison (should be TRUE when comparison is false)
run_test \
    "NOT with == (negated false)" \
    '{{#if ! ARCH == "sve"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'ARCH=neon'

# Test 3.2: NOT with == comparison (should be FALSE when comparison is true)
run_test \
    "NOT with == (negated true)" \
    '{{#if ! ARCH == "sve"}}MATCH{{else}}NO MATCH{{/if}}' \
    "NO MATCH" \
    'ARCH=sve'

# Test 3.3: NOT with != comparison
run_test \
    "NOT with !=" \
    '{{#if ! ARCH != "sve"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'ARCH=sve'

# =============================================================================
# Test Group 4: Complex nested logical expressions
# =============================================================================

echo ""
echo "=== Test Group 4: Complex nested expressions ==="

# Test 4.1: OR chaining (first in chain evaluates left-to-right)
# Note: AWK evaluates || left-to-right, so "a || b || c" = "(a || b) || c"
run_test \
    "OR chain (first match)" \
    '{{#if VAR == "a" || VAR == "b"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'VAR=a'

# Test 4.2: OR chaining (last item)
run_test \
    "OR chain (last match)" \
    '{{#if VAR == "a" || VAR == "b"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'VAR=b'

# Test 4.3: OR chaining (no match)
run_test \
    "OR chain (no match)" \
    '{{#if VAR == "a" || VAR == "b"}}MATCH{{else}}NO MATCH{{/if}}' \
    "NO MATCH" \
    'VAR=c'

# Note: dap_tpl doesn't support explicit parentheses in conditions
# Operator precedence is: NOT > AND > OR (standard precedence)
# Complex nested expressions are evaluated left-to-right within same precedence

# =============================================================================
# Test Group 5: Edge cases with quotes and special characters
# =============================================================================

echo ""
echo "=== Test Group 5: Edge cases with quotes and special characters ==="

# Note: Values with embedded quotes or special chars (|, @@) are not recommended
# as they may conflict with internal delimiters. This is a known limitation.

# Test 5.1: Empty string comparison with OR
run_test \
    "Empty string with OR" \
    '{{#if VAR == "" || VAR == "default"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'VAR=""'

# Test 5.2: Numeric comparisons with OR
run_test \
    "Numeric comparison with OR" \
    '{{#if NUM == "1" || NUM == "2"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'NUM=2'

# Test 5.3: OR with greater-than comparisons
run_test \
    "OR with > comparisons" \
    '{{#if NUM > "5" || NUM < "2"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'NUM=10'

# Test 5.4: AND with >= and <= comparisons
run_test \
    "AND with >= and <=" \
    '{{#if NUM >= "1" && NUM <= "10"}}MATCH{{else}}NO MATCH{{/if}}' \
    "MATCH" \
    'NUM=5'

# =============================================================================
# Test Group 6: Real-world use cases (from JSON SIMD template)
# =============================================================================

echo ""
echo "=== Test Group 6: Real-world use cases ==="

# Test 6.1: SVE detection (the exact case that triggered the bug)
run_test \
    "SVE/SVE2 detection (NEON)" \
    '{{#if ARCH_LOWER == "sve" || ARCH_LOWER == "sve2"}}SVE{{else}}NOT SVE{{/if}}' \
    "NOT SVE" \
    'ARCH_LOWER=neon'

# Test 6.2: SVE detection (SVE)
run_test \
    "SVE/SVE2 detection (SVE)" \
    '{{#if ARCH_LOWER == "sve" || ARCH_LOWER == "sve2"}}SVE{{else}}NOT SVE{{/if}}' \
    "SVE" \
    'ARCH_LOWER=sve'

# Test 6.3: Non-SVE detection (the complementary case)
run_test \
    "Non-SVE detection (NEON)" \
    '{{#if ARCH_LOWER != "sve" && ARCH_LOWER != "sve2"}}NON-SVE{{else}}SVE{{/if}}' \
    "NON-SVE" \
    'ARCH_LOWER=neon'

# Test 6.4: Non-SVE detection (SVE)
run_test \
    "Non-SVE detection (SVE)" \
    '{{#if ARCH_LOWER != "sve" && ARCH_LOWER != "sve2"}}NON-SVE{{else}}SVE{{/if}}' \
    "SVE" \
    'ARCH_LOWER=sve'

# Test 6.5: x86 architecture detection (chained OR)
run_test \
    "x86 architecture detection (chained)" \
    '{{#if ARCH == "sse2" || ARCH == "avx2"}}X86{{else}}NOT X86{{/if}}' \
    "X86" \
    'ARCH=avx2'

# Test 6.6: ARM architecture detection (chained OR)
run_test \
    "ARM architecture detection (chained)" \
    '{{#if ARCH == "neon" || ARCH == "sve"}}ARM{{else}}NOT ARM{{/if}}' \
    "ARM" \
    'ARCH=neon'

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "Test Results:"
echo "  PASSED: $PASS_COUNT"
echo "  FAILED: $FAIL_COUNT"
echo "=========================================="

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "✅ All tests PASSED"
    exit 0
else
    echo "❌ Some tests FAILED"
    exit 1
fi

