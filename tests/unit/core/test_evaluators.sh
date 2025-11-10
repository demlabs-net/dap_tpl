#!/bin/bash
# Test runner for evaluator tests

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../../.." && pwd)"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export AWKPATH="${DAP_TPL_DIR}"

echo "Running evaluator tests..."

failed=0
passed=0

for test_file in "$TEST_DIR"/evaluator_tests/*.awk; do
    if [ ! -f "$test_file" ]; then
        continue
    fi
    
    test_name=$(basename "$test_file" .awk)
    echo -n "  $test_name: "
    
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

