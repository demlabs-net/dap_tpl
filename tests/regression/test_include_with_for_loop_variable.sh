#!/bin/bash
# Regression test for {{#include}} with {{#for}} loop using environment variables
# This test reproduces the bug where PARAM_COUNTS_LIST is not visible in included template
#
# Bug: When main template includes sub-template with {{#for loop in VAR}},
# the VAR from environment is not visible inside the included template
#
# Expected: Variables exported before dap_tpl.sh should be visible in {{#include}}d templates

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_pass() {
    echo -e "${GREEN}PASS${NC}: $1"
}

print_fail() {
    echo -e "${RED}FAIL${NC}: $1"
}

# Cleanup
cleanup() {
    rm -f /tmp/test_include_for_*.tpl /tmp/test_include_for_*.txt
}
trap cleanup EXIT

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export AWKPATH="${DAP_TPL_DIR}"

# Test 1: Basic {{#for}} with environment variable in included template
echo "Test 1: {{#for}} with environment variable in included template"

# Create main template
cat > /tmp/test_include_for_main.tpl << 'EOF'
MAIN START
{{#include "/tmp/test_include_for_sub.tpl"}}
MAIN END
EOF

# Create sub-template with for loop
cat > /tmp/test_include_for_sub.tpl << 'EOF'
SUB START
{{#for item in TEST_LIST}}
ITEM: {{item}}
{{/for}}
SUB END
EOF

# Export variable
export TEST_LIST="a|b|c"

# Process template
OUTPUT=$(bash "${DAP_TPL_DIR}/dap_tpl.sh" /tmp/test_include_for_main.tpl 2>&1)

# Verify output
if echo "$OUTPUT" | grep -q "MAIN START"; then
    print_pass "Main start marker present"
else
    print_fail "Main start marker missing"
    echo "Output:"
    echo "$OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -q "SUB START"; then
    print_pass "Sub start marker present"
else
    print_fail "Sub start marker missing"
    echo "Output:"
    echo "$OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -q "ITEM: a"; then
    print_pass "First item from for loop present"
else
    print_fail "First item from for loop missing - VARIABLE NOT VISIBLE IN INCLUDE!"
    echo "Output:"
    echo "$OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -q "ITEM: b"; then
    print_pass "Second item from for loop present"
else
    print_fail "Second item from for loop missing"
    echo "Output:"
    echo "$OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -q "ITEM: c"; then
    print_pass "Third item from for loop present"
else
    print_fail "Third item from for loop missing"
    echo "Output:"
    echo "$OUTPUT"
    exit 1
fi

echo ""
echo "Test 2: {{#for}} with TEMPLATES_DIR relative include"

# Create templates directory
mkdir -p /tmp/test_include_for_templates
export TEMPLATES_DIR="/tmp/test_include_for_templates"

# Create main template
cat > /tmp/test_include_for_main2.tpl << 'EOF'
MAIN2 START
{{#include "sub_with_for.tpl"}}
MAIN2 END
EOF

# Create sub-template in TEMPLATES_DIR
cat > /tmp/test_include_for_templates/sub_with_for.tpl << 'EOF'
{{#if PARAM_COUNTS_LIST}}
PARAM_COUNTS_LIST exists
{{#for count in PARAM_COUNTS_LIST}}
COUNT: {{count}}
{{/for}}
{{else}}
PARAM_COUNTS_LIST is empty or not set
{{/if}}
EOF

# Export variable (simulating mock generator)
export PARAM_COUNTS_LIST="0|2|5"

# Process template
OUTPUT2=$(bash "${DAP_TPL_DIR}/dap_tpl.sh" /tmp/test_include_for_main2.tpl 2>&1)

# Verify output
if echo "$OUTPUT2" | grep -q "PARAM_COUNTS_LIST exists"; then
    print_pass "PARAM_COUNTS_LIST visible in included template"
else
    print_fail "PARAM_COUNTS_LIST NOT visible in included template - THIS IS THE BUG!"
    echo "Output:"
    echo "$OUTPUT2"
    exit 1
fi

if echo "$OUTPUT2" | grep -q "COUNT: 0"; then
    print_pass "First count (0) present"
else
    print_fail "First count (0) missing"
    echo "Output:"
    echo "$OUTPUT2"
    exit 1
fi

if echo "$OUTPUT2" | grep -q "COUNT: 2"; then
    print_pass "Second count (2) present"
else
    print_fail "Second count (2) missing"
    echo "Output:"
    echo "$OUTPUT2"
    exit 1
fi

if echo "$OUTPUT2" | grep -q "COUNT: 5"; then
    print_pass "Third count (5) present"
else
    print_fail "Third count (5) missing"
    echo "Output:"
    echo "$OUTPUT2"
    exit 1
fi

# Cleanup templates dir
rm -rf /tmp/test_include_for_templates

echo ""
echo "All tests passed!"
