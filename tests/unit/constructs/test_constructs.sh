#!/bin/bash
# Test runner for constructs tests
# Scans constructs/ directory and runs all .awk test files

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../../.." && pwd)"
TESTS_DIR="${TEST_DIR}"

if [ ! -d "$TESTS_DIR" ]; then
    echo "ERROR: Test directory not found: $TESTS_DIR"
    exit 1
fi

# Export SCRIPTS_DIR and AWKPATH for @include to work
export SCRIPTS_DIR="${DAP_TPL_DIR}"
export AWKPATH="${DAP_TPL_DIR}"

echo "Running constructs tests..."

failed=0
passed=0

# Find and run all .awk test files
for test_file in "$TESTS_DIR"/*.awk; do
    if [ ! -f "$test_file" ]; then
        continue
    fi
    
    test_name=$(basename "$test_file" .awk)
    echo -n "  $test_name: "
    
    # Run test with gawk from dap_tpl directory where modules are visible
    if result=$(cd "$DAP_TPL_DIR" && gawk -f "$test_file" <<< "" 2>&1); then
        if echo "$result" | grep -q "^PASS$"; then
            echo "PASS"
            ((passed++)) || true
        else
            echo "FAIL"
            echo "    Output: $result"
            ((failed++)) || true
        fi
    else
        echo "FAIL"
        echo "    Error: $result"
        ((failed++)) || true
    fi
done

echo ""
if [ $failed -eq 0 ]; then
    echo "All $passed tests passed!"
    exit 0
else
    echo "$failed test(s) failed, $passed test(s) passed"
    exit 1
fi

