#!/bin/bash
# Integration test: full template processing
# Tests complete template processing pipeline

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
FIXTURES_DIR="${TEST_DIR}/../fixtures"

# Source dap_tpl.sh
source "${DAP_TPL_DIR}/dap_tpl.sh"

# Set SCRIPTS_DIR and TEMPLATES_DIR
export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR="$(cd "${DAP_TPL_DIR}/.." && pwd)/templates"

# Create test template
test_template=$(mktemp)
cat > "$test_template" << 'EOF'
// Auto-generated header
#ifndef TEST_HEADER_H
#define TEST_HEADER_H

#include "test.h"

{{#if CUSTOM_MOCKS_LIST}}
// Custom mocks section
{{#for mock_entry in CUSTOM_MOCKS_LIST}}
#include "{{mock_entry}}_mock.h"
{{/for}}
{{/if}}

#endif // TEST_HEADER_H
EOF

# Create output file
test_output=$(mktemp)

# Test with CUSTOM_MOCKS_LIST
export CUSTOM_MOCKS_LIST="mock1|mock2|mock3"
replace_template_placeholders "$test_template" "$test_output" CUSTOM_MOCKS_LIST="$CUSTOM_MOCKS_LIST"

# Verify output
if ! grep -q "mock1_mock.h" "$test_output"; then
    echo "FAIL: mock1_mock.h not found in output"
    exit 1
fi

if ! grep -q "mock2_mock.h" "$test_output"; then
    echo "FAIL: mock2_mock.h not found in output"
    exit 1
fi

if ! grep -q "mock3_mock.h" "$test_output"; then
    echo "FAIL: mock3_mock.h not found in output"
    exit 1
fi

# Cleanup
rm -f "$test_template" "$test_output"

echo "PASS: Full template processing test"

