#!/bin/bash
# CORRECT regression test that reproduces the REAL bug
# This test calls replace_template_placeholders via sourcing, like mock generator does

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_pass() { echo -e "${GREEN}PASS${NC}: $1"; }
print_fail() { echo -e "${RED}FAIL${NC}: $1"; }

cleanup() {
    rm -f /tmp/test_real_bug_*.tpl /tmp/test_real_bug_*.txt
    rm -rf /tmp/test_real_bug_templates
}
trap cleanup EXIT

# SOURCE dap_tpl.sh to get replace_template_placeholders function
source "${DAP_TPL_DIR}/dap_tpl.sh"

echo "Test: REAL bug reproduction - calling replace_template_placeholders as function"

# Create templates directory
mkdir -p /tmp/test_real_bug_templates
export TEMPLATES_DIR="/tmp/test_real_bug_templates"
export SCRIPTS_DIR="${DAP_TPL_DIR}"
export AWKPATH="${DAP_TPL_DIR}"

# Create main template
cat > /tmp/test_real_bug_main.tpl << 'EOF'
MAIN START
{{#include "sub_template.tpl"}}
MAIN END
EOF

# Create sub-template with for loop (like mock_map_param_count_routing.h.tpl)
cat > /tmp/test_real_bug_templates/sub_template.tpl << 'EOF'
SUB START
{{#if PARAM_COUNTS_LIST}}
PARAM_COUNTS_LIST exists: {{PARAM_COUNTS_LIST}}
{{#for count in PARAM_COUNTS_LIST}}
COUNT: {{count}}
{{/for}}
{{else}}
ERROR: PARAM_COUNTS_LIST not visible!
{{/if}}
SUB END
EOF

# Export variable BEFORE calling function (like in dap_mock_autowrap.sh)
export PARAM_COUNTS_LIST="0|2|5"
export MAX_ARGS_COUNT="12"

echo "Exported variables:"
env | grep -E "^PARAM_COUNTS_LIST=|^MAX_ARGS_COUNT="

# Call replace_template_placeholders AS FUNCTION (like real code does)
replace_template_placeholders "/tmp/test_real_bug_main.tpl" "/tmp/test_real_bug_output.txt"

# Read output
OUTPUT=$(cat /tmp/test_real_bug_output.txt 2>/dev/null || echo "FILE NOT CREATED")

echo ""
echo "=== OUTPUT ==="
echo "$OUTPUT"
echo "=============="
echo ""

# Verify
if echo "$OUTPUT" | grep -q "PARAM_COUNTS_LIST exists"; then
    print_pass "PARAM_COUNTS_LIST visible"
else
    print_fail "PARAM_COUNTS_LIST NOT visible - BUG REPRODUCED!"
    exit 1
fi

if echo "$OUTPUT" | grep -q "COUNT: 0"; then
    print_pass "First count present"
else
    print_fail "First count missing - FOR LOOP FAILED!"
    exit 1
fi

if echo "$OUTPUT" | grep -q "COUNT: 2"; then
    print_pass "Second count present"  
else
    print_fail "Second count missing"
    exit 1
fi

if echo "$OUTPUT" | grep -q "COUNT: 5"; then
    print_pass "Third count present"
else
    print_fail "Third count missing"
    exit 1
fi

echo ""
echo "All tests passed!"
