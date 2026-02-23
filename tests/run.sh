#!/bin/bash

# Detect available AWK
AWK_CMD="${AWK_CMD:-mawk}"
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Universal test runner for dap_tpl
# Usage:
#   ./run.sh all                    - Run all tests
#   ./run.sh unit                   - Run all unit tests
#   ./run.sh integration            - Run all integration tests
#   ./run.sh regression             - Run all regression tests
#   ./run.sh unit/core              - Run all tests in unit/core
#   ./run.sh unit/core/test_marker_parser  - Run specific test runner
#   ./run.sh unit/core/marker_parser_tests/test_parse_simple_marker  - Run specific test file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export SCRIPTS_DIR="${DAP_TPL_DIR}"
export AWKPATH="${DAP_TPL_DIR}"

# Build engine before running tests
echo "Building AWK engine..."
if ! "${DAP_TPL_DIR}/utils/build_engine.sh" >/dev/null 2>&1; then
    echo "ERROR: Failed to build engine" >&2
    exit 1
fi
ENGINE_FILE="/tmp/dap_tpl_engine.awk"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to run a single .awk test file  
run_awk_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .awk)
    
    # Preprocess the test file to expand @include directives
    local preprocessed="/tmp/dap_tpl_test_$$.awk"
    if ! AWKPATH="${DAP_TPL_DIR}" "${DAP_TPL_DIR}/utils/awk_include_preprocessor.sh" "$test_file" "${DAP_TPL_DIR}" > "$preprocessed" 2>/dev/null; then
        echo "FAIL"
        echo "    Error: Failed to preprocess test file"
        rm -f "$preprocessed"
        return 1
    fi
    
    # Run preprocessed test
    local result
    if result=$(cd "$DAP_TPL_DIR" && "$AWK_CMD" -f "$preprocessed" <<< "" 2>&1); then
        rm -f "$preprocessed"
        if echo "$result" | grep -q "^PASS$"; then
            echo "PASS"
            return 0
        else
            echo "FAIL"
            echo "    Output: $result"
            return 1
        fi
    else
        rm -f "$preprocessed"
        echo "FAIL"
        echo "    Error: $result"
        return 1
    fi
}

# Function to run a test runner script
run_test_runner() {
    local runner_file="$1"
    local runner_name=$(basename "$runner_file" .sh)
    
    if [ ! -x "$runner_file" ]; then
        chmod +x "$runner_file"
    fi
    
    print_info "Running $runner_name..."
    local output
    if output=$(bash "$runner_file" 2>&1); then
        echo "$output"
        return 0
    else
        echo "$output"
        print_error "❌ Test failed: $runner_name"
        return 1
    fi
}

# Function to find and run all .awk test files in a directory
run_awk_tests_in_dir() {
    local test_dir="$1"
    local failed=0
    local passed=0
    
    if [ ! -d "$test_dir" ]; then
        print_error "Test directory not found: $test_dir"
        return 1
    fi
    
    for test_file in "$test_dir"/*.awk; do
        if [ ! -f "$test_file" ]; then
            continue
        fi
        
        test_name=$(basename "$test_file" .awk)
        echo -n "  $test_name: "
        
        if run_awk_test "$test_file"; then
            ((passed++)) || true
        else
            ((failed++)) || true
        fi
    done
    
    if [ $failed -eq 0 ] && [ $passed -gt 0 ]; then
        echo ""
        print_success "All $passed tests passed!"
        return 0
    elif [ $failed -gt 0 ]; then
        echo ""
        print_error "$failed test(s) failed, $passed test(s) passed"
        return 1
    else
        return 0
    fi
}

# Function to run all tests in a directory (both .sh runners and .awk files)
run_tests_in_dir() {
    local test_dir="$1"
    local failed=0
    local passed=0
    local found_any=0
    local failed_tests=()
    
    if [ ! -d "$test_dir" ]; then
        print_error "Test directory not found: $test_dir"
        return 1
    fi
    
    # Run all .sh test runners (recursively)
    # These runners handle their own _tests subdirectories
    while IFS= read -r runner_file; do
        if [ -f "$runner_file" ]; then
            found_any=1
            runner_name=$(basename "$runner_file" .sh)
            if run_test_runner "$runner_file"; then
                ((passed++)) || true
                ((TOTAL_PASSED++)) || true
            else
                ((failed++)) || true
                ((TOTAL_FAILED++)) || true
                failed_tests+=("$runner_name")
                FAILED_TEST_LIST+=("$runner_name")
            fi
            echo ""
        fi
    done < <(find "$test_dir" -name "test_*.sh" -type f | sort)
    
    # Also find standalone _tests directories that don't have a runner
    # (for cases where tests are organized without a runner script)
    while IFS= read -r subdir; do
        # Check if there's a corresponding runner script
        subdir_parent=$(dirname "$subdir")
        subdir_name=$(basename "$subdir" _tests)
        
        # Try multiple possible runner names
        runner_file="${subdir_parent}/test_${subdir_name}.sh"
        runner_file_plural="${subdir_parent}/test_${subdir_name}s.sh"
        
        if [ -f "$runner_file" ] || [ -f "$runner_file_plural" ]; then
            # Runner exists, skip (it will be handled by the runner loop above)
            continue
        fi
        
        # No runner found, run tests directly
        found_any=1
        subdir_test_name=$(basename "$subdir")
        print_info "Running $subdir_test_name tests..."
        if run_awk_tests_in_dir "$subdir"; then
            ((passed++)) || true
            ((TOTAL_PASSED++)) || true
        else
            ((failed++)) || true
            ((TOTAL_FAILED++)) || true
            FAILED_TEST_LIST+=("$subdir_test_name")
        fi
        echo ""
    done < <(find "$test_dir" -type d -name "*_tests" | sort)
    
    if [ $found_any -eq 0 ]; then
        print_warning "No tests found in $test_dir"
        return 0
    fi
    
    if [ $failed -eq 0 ] && [ $passed -gt 0 ]; then
        return 0
    elif [ $failed -gt 0 ]; then
        # Print list of failed tests in this directory
        if [ ${#failed_tests[@]} -gt 0 ]; then
            print_error "Failed tests in $(basename "$test_dir"):"
            for test in "${failed_tests[@]}"; do
                echo "  - $test"
            done
        fi
        return 1
    else
        return 0
    fi
}

# Global counters for detailed statistics
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_TEST_LIST=()

# Main logic
TARGET="${1:-all}"

if [ "$TARGET" == "all" ]; then
    print_info "Running all dap_tpl tests..."
    echo ""
    
    # Run unit tests
    print_info "=== Unit Tests ==="
    UNIT_FAILED_BEFORE=${#FAILED_TEST_LIST[@]}
    if run_tests_in_dir "${SCRIPT_DIR}/unit"; then
        unit_result=0
    else
        unit_result=1
    fi
    UNIT_FAILED_AFTER=${#FAILED_TEST_LIST[@]}
    echo ""
    
    # Run integration tests
    print_info "=== Integration Tests ==="
    INTEGRATION_FAILED_BEFORE=${#FAILED_TEST_LIST[@]}
    if run_tests_in_dir "${SCRIPT_DIR}/integration"; then
        integration_result=0
    else
        integration_result=1
    fi
    INTEGRATION_FAILED_AFTER=${#FAILED_TEST_LIST[@]}
    echo ""
    
    # Run regression tests
    print_info "=== Regression Tests ==="
    REGRESSION_FAILED_BEFORE=${#FAILED_TEST_LIST[@]}
    if run_tests_in_dir "${SCRIPT_DIR}/regression"; then
        regression_result=0
    else
        regression_result=1
    fi
    REGRESSION_FAILED_AFTER=${#FAILED_TEST_LIST[@]}
    
    # Print detailed summary
    echo ""
    echo "==========================================="
    print_info "TEST SUMMARY"
    echo "==========================================="
    echo "Total tests run:    $((TOTAL_PASSED + TOTAL_FAILED))"
    echo "Passed:             $TOTAL_PASSED"
    echo "Failed:             $TOTAL_FAILED"
    echo ""
    
    if [ $TOTAL_FAILED -eq 0 ]; then
        print_success "✅ ALL TESTS PASSED!"
        exit 0
    else
        print_error "❌ FAILED TESTS:"
        echo ""
        
        # Group by category
        if [ $unit_result -ne 0 ]; then
            print_error "Unit Tests ($((UNIT_FAILED_AFTER - UNIT_FAILED_BEFORE)) failed):"
            for ((i=UNIT_FAILED_BEFORE; i<UNIT_FAILED_AFTER; i++)); do
                echo "  - ${FAILED_TEST_LIST[$i]}"
            done
            echo ""
        fi
        
        if [ $integration_result -ne 0 ]; then
            print_error "Integration Tests ($((INTEGRATION_FAILED_AFTER - INTEGRATION_FAILED_BEFORE)) failed):"
            for ((i=INTEGRATION_FAILED_BEFORE; i<INTEGRATION_FAILED_AFTER; i++)); do
                echo "  - ${FAILED_TEST_LIST[$i]}"
            done
            echo ""
        fi
        
        if [ $regression_result -ne 0 ]; then
            print_error "Regression Tests ($((REGRESSION_FAILED_AFTER - REGRESSION_FAILED_BEFORE)) failed):"
            for ((i=REGRESSION_FAILED_BEFORE; i<REGRESSION_FAILED_AFTER; i++)); do
                echo "  - ${FAILED_TEST_LIST[$i]}"
            done
            echo ""
        fi
        
        echo "==========================================="
        exit 1
    fi
    
elif [ "$TARGET" == "unit" ]; then
    print_info "Running all unit tests..."
    echo ""
    if run_tests_in_dir "${SCRIPT_DIR}/unit"; then
        exit 0
    else
        exit 1
    fi
    
elif [ "$TARGET" == "integration" ]; then
    print_info "Running all integration tests..."
    echo ""
    if run_tests_in_dir "${SCRIPT_DIR}/integration"; then
        exit 0
    else
        exit 1
    fi
    
elif [ "$TARGET" == "regression" ]; then
    print_info "Running all regression tests..."
    echo ""
    if run_tests_in_dir "${SCRIPT_DIR}/regression"; then
        exit 0
    else
        exit 1
    fi
    
elif [ -f "${SCRIPT_DIR}/${TARGET}.sh" ]; then
    # Specific test runner script
    run_test_runner "${SCRIPT_DIR}/${TARGET}.sh"
    exit $?
    
elif [ -f "${SCRIPT_DIR}/${TARGET}.awk" ]; then
    # Specific .awk test file
    print_info "Running test: $TARGET"
    if run_awk_test "${SCRIPT_DIR}/${TARGET}.awk"; then
        exit 0
    else
        exit 1
    fi
    
elif [ -d "${SCRIPT_DIR}/${TARGET}" ]; then
    # Directory - run all tests in it
    print_info "Running tests in: $TARGET"
    echo ""
    if run_tests_in_dir "${SCRIPT_DIR}/${TARGET}"; then
        exit 0
    else
        exit 1
    fi
    
else
    print_error "Unknown test target: $TARGET"
    echo ""
    echo "Usage: $0 [all|unit|integration|regression|path/to/test]"
    echo ""
    echo "Examples:"
    echo "  $0 all                                          # Run all tests"
    echo "  $0 unit                                         # Run all unit tests"
    echo "  $0 integration                                  # Run all integration tests"
    echo "  $0 regression                                   # Run all regression tests"
    echo "  $0 unit/core                                    # Run all tests in unit/core"
    echo "  $0 unit/core/test_marker_parser                 # Run specific test runner"
    echo "  $0 unit/core/marker_parser_tests/test_parse_simple_marker  # Run specific test file"
    exit 1
fi

