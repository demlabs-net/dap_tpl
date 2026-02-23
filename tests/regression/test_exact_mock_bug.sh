#!/bin/bash
# Regression: variable visibility in {{#include}} when --extensions-dir is used
# Reproduces the exact bug where env variables became invisible to included
# templates when the engine was built with extension modules.

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_pass() { echo -e "${GREEN}PASS${NC}: $1"; }
print_fail() { echo -e "${RED}FAIL${NC}: $1"; }

cleanup() {
    rm -f /tmp/test_exact_bug_*.tpl /tmp/test_exact_bug_*.txt
    rm -rf /tmp/test_exact_bug_templates /tmp/test_exact_bug_ext
}
trap cleanup EXIT

source "${DAP_TPL_DIR}/dap_tpl.sh"

echo "Test: variable visibility in #include with --extensions-dir"

mkdir -p /tmp/test_exact_bug_templates
mkdir -p /tmp/test_exact_bug_ext
export TEMPLATES_DIR="/tmp/test_exact_bug_templates"
export SCRIPTS_DIR="${DAP_TPL_DIR}"
export AWKPATH="${DAP_TPL_DIR}"

# Minimal no-op extension to trigger the extensions code path
cat > /tmp/test_exact_bug_ext/noop_ext.awk << 'AWKEOF'
function noop_extension_stub() { return 0 }
AWKEOF

cat > /tmp/test_exact_bug_main.tpl << 'EOF'
// Main template
{{#include "sub_with_for.tpl"}}
// End main
EOF

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

export PARAM_COUNTS_LIST="0|2|5"
export MAX_ARGS_COUNT="12"

replace_template_placeholders \
    "/tmp/test_exact_bug_main.tpl" \
    "/tmp/test_exact_bug_output.txt" \
    --extensions-dir "/tmp/test_exact_bug_ext"

OUTPUT=$(cat /tmp/test_exact_bug_output.txt 2>/dev/null || echo "FILE NOT CREATED")

echo ""
echo "=== OUTPUT ==="
echo "$OUTPUT"
echo "=============="
echo ""

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
