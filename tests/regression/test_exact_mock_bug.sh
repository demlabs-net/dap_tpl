#!/bin/bash
# EXACT reproduction - via replace_template_placeholders_with_mocking wrapper

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
MOCKS_DIR="$(cd "$TEST_DIR/../../../../dap-sdk/module/test/mocks" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_pass() { echo -e "${GREEN}PASS${NC}: $1"; }
print_fail() { echo -e "${RED}FAIL${NC}: $1"; }

cleanup() {
    rm -f /tmp/test_exact_bug_*.tpl /tmp/test_exact_bug_*.txt
    rm -rf /tmp/test_exact_bug_templates
}
trap cleanup EXIT

# SOURCE the REAL mock common file to get the wrapper
source "${MOCKS_DIR}/lib/dap_mock_common.sh"

echo "Test: EXACT bug reproduction - via replace_template_placeholders_with_mocking"

# Create templates directory  
mkdir -p /tmp/test_exact_bug_templates
export TEMPLATES_DIR="/tmp/test_exact_bug_templates"

# Create main template (like mock_map_macros.h.tpl)
cat > /tmp/test_exact_bug_main.tpl << 'EOF'
// Main template
{{#include "sub_with_for.tpl"}}
// End main
EOF

# Create sub-template (like mock_map_param_count_routing.h.tpl)
cat > /tmp/test_exact_bug_templates/sub_with_for.tpl << 'EOF'
{{#if PARAM_COUNTS_LIST}}
// PARAM_COUNTS_LIST found
{{#for count in PARAM_COUNTS_LIST}}
#define ROUTE_{{count}} value_{{count}}
{{/for}}
{{else}}
// ERROR: PARAM_COUNTS_LIST not found!
{{/if}}
EOF

# Export variables (like in dap_mock_autowrap.sh)
export PARAM_COUNTS_LIST="0|2|5"
export MAX_ARGS_COUNT="12"

echo "Exported variables:"
env | grep -E "^PARAM_COUNTS_LIST=|^MAX_ARGS_COUNT="

# Call via wrapper (EXACT path as real code)
replace_template_placeholders_with_mocking "/tmp/test_exact_bug_main.tpl" "/tmp/test_exact_bug_output.txt"

# Read output
OUTPUT=$(cat /tmp/test_exact_bug_output.txt 2>/dev/null || echo "FILE NOT CREATED")

echo ""
echo "=== OUTPUT ==="
echo "$OUTPUT"
echo "=============="
echo ""

# Verify
if echo "$OUTPUT" | grep -q "PARAM_COUNTS_LIST found"; then
    print_pass "PARAM_COUNTS_LIST visible in included template"
else
    print_fail "PARAM_COUNTS_LIST NOT visible - BUG REPRODUCED!"
    exit 1
fi

if echo "$OUTPUT" | grep -q "#define ROUTE_0"; then
    print_pass "ROUTE_0 macro generated"
else
    print_fail "ROUTE_0 macro missing - FOR LOOP FAILED!"
    exit 1
fi

if echo "$OUTPUT" | grep -q "#define ROUTE_2"; then
    print_pass "ROUTE_2 macro generated"
else
    print_fail "ROUTE_2 macro missing"
    exit 1
fi

if echo "$OUTPUT" | grep -q "#define ROUTE_5"; then
    print_pass "ROUTE_5 macro generated"
else
    print_fail "ROUTE_5 macro missing"
    exit 1
fi

echo ""
echo "All tests passed!"
