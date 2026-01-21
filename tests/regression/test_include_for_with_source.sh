#!/bin/bash
# Pure dap_tpl test: {{#include}} with {{#for}} using exported variables
# Tests that variables exported before calling replace_template_placeholders 
# are visible inside included templates

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_pass() { echo -e "${GREEN}PASS${NC}: $1"; }
print_fail() { echo -e "${RED}FAIL${NC}: $1"; }

cleanup() {
    rm -f /tmp/dap_tpl_test_*.tpl /tmp/dap_tpl_test_*.txt
    rm -rf /tmp/dap_tpl_test_templates
}
trap cleanup EXIT

# Create clean test environment
mkdir -p /tmp/dap_tpl_test_templates

# Test setup
export TEMPLATES_DIR="/tmp/dap_tpl_test_templates"
export SCRIPTS_DIR="${DAP_TPL_DIR}"
export AWKPATH="${DAP_TPL_DIR}"

# Export test variables
export MY_LIST="alpha|beta|gamma"
export MY_COUNT="3"

echo "=== Test: {{#include}} with {{#for}} loop on exported variable ==="
echo "Exported: MY_LIST=$MY_LIST"
echo ""

# Create main template
cat > /tmp/dap_tpl_test_main.tpl << 'EOF'
BEFORE INCLUDE
{{#include "sub.tpl"}}
AFTER INCLUDE
EOF

# Create sub-template with {{#for}} loop
cat > /tmp/dap_tpl_test_templates/sub.tpl << 'EOF'
SUB STARTS
{{#if MY_LIST}}
Found MY_LIST: {{MY_LIST}}
{{#for item in MY_LIST}}
  - Item: {{item}}
{{/for}}
{{else}}
ERROR: MY_LIST not found!
{{/if}}
SUB ENDS
EOF

# Method 1: Call via bash command (this should work)
echo "Method 1: Direct bash call"
bash "${DAP_TPL_DIR}/dap_tpl.sh" /tmp/dap_tpl_test_main.tpl /tmp/dap_tpl_test_out1.txt 2>&1
OUT1=$(cat /tmp/dap_tpl_test_out1.txt)

if echo "$OUT1" | grep -q "Found MY_LIST"; then
    print_pass "Method 1: Variable visible"
else
    print_fail "Method 1: Variable NOT visible"
    echo "Output:"
    echo "$OUT1"
fi

if echo "$OUT1" | grep -q "Item: alpha"; then
    print_pass "Method 1: First item present"
else
    print_fail "Method 1: First item missing"
fi

echo ""

# Method 2: Source and call as function (like mock generator does)
echo "Method 2: Source dap_tpl.sh and call replace_template_placeholders as function"

# Source the library
source "${DAP_TPL_DIR}/dap_tpl.sh"

# Call the function
replace_template_placeholders /tmp/dap_tpl_test_main.tpl /tmp/dap_tpl_test_out2.txt

OUT2=$(cat /tmp/dap_tpl_test_out2.txt)

if echo "$OUT2" | grep -q "Found MY_LIST"; then
    print_pass "Method 2: Variable visible"
else
    print_fail "Method 2: Variable NOT visible - BUG FOUND!"
    echo "Output:"
    echo "$OUT2"
    exit 1
fi

if echo "$OUT2" | grep -q "Item: alpha"; then
    print_pass "Method 2: First item present"
else
    print_fail "Method 2: First item missing - FOR LOOP FAILED!"
    echo "Output:"
    echo "$OUT2"
    exit 1
fi

if echo "$OUT2" | grep -q "Item: beta"; then
    print_pass "Method 2: Second item present"
else
    print_fail "Method 2: Second item missing"
    exit 1
fi

echo ""
echo "All tests PASSED - no bug found!"
