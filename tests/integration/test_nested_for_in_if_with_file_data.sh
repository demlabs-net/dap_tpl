#!/bin/bash
# Integration test for nested {{#for}} inside {{#if}} with file-based data
# This test reproduces the issue where NORMALIZATION_MACROS_DATA is passed via @filename
# and the nested {{#for}} loop inside {{#if}} is not processed correctly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATES_DIR="$(cd "$DAP_TPL_DIR/../templates" && pwd)"
FIXTURES_DIR="$(cd "$SCRIPT_DIR/../fixtures" && pwd)"

# Load dap_tpl functions
source "${DAP_TPL_DIR}/dap_tpl.sh"
source "${DAP_TPL_DIR}/dap_tpl_lib.sh"

# Colors for output
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

# Create temporary files
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

# Use template from fixtures directory
TEMPLATE_FILE="${FIXTURES_DIR}/nested_for_in_if.tpl"
OUTPUT_FILE="${TEMP_DIR}/test_output.h"
DATA_FILE="${TEMP_DIR}/test_data.txt"

# Verify template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Write test data to file (pipe-separated entries, newline-separated list)
# Format: macro_key|base_type
cat > "$DATA_FILE" <<'DATAEOF'
dap_list_t*|dap_list_t
int|int
char*|char
DATAEOF

print_info "Test: Nested {{#for}} inside {{#if}} with file-based data"
echo ""
print_info "Template file: $TEMPLATE_FILE"
print_info "Data file: $DATA_FILE"
print_info "Output file: $OUTPUT_FILE"
echo ""

# Run replace_template_placeholders with @filename syntax
print_info "Running replace_template_placeholders..."
if replace_template_placeholders "$TEMPLATE_FILE" "$OUTPUT_FILE" "NORMALIZATION_MACROS_DATA=@$DATA_FILE"; then
    print_success "Template processing completed"
else
    print_error "Template processing failed"
    exit 1
fi

echo ""
print_info "Generated output:"
echo "----------------------------------------"
cat "$OUTPUT_FILE"
echo "----------------------------------------"
echo ""

# Verify output
FAILED=0

# Check 1: Output should not contain unprocessed template constructs
if grep -q "{{#if NORMALIZATION_MACROS_DATA}}" "$OUTPUT_FILE"; then
    print_error "FAIL: Template contains unprocessed {{#if NORMALIZATION_MACROS_DATA}}"
    FAILED=1
fi

if grep -q "{{#for entry in NORMALIZATION_MACROS_DATA}}" "$OUTPUT_FILE"; then
    print_error "FAIL: Template contains unprocessed {{#for entry in NORMALIZATION_MACROS_DATA}}"
    FAILED=1
fi

# Check 2: Output should contain processed macros
if ! grep -q "#define TEST_MACRO_dap_list_t\*" "$OUTPUT_FILE"; then
    print_error "FAIL: Expected #define TEST_MACRO_dap_list_t* not found"
    FAILED=1
fi

if ! grep -q "#define TEST_MACRO_int" "$OUTPUT_FILE"; then
    print_error "FAIL: Expected #define TEST_MACRO_int not found"
    FAILED=1
fi

if ! grep -q "#define TEST_MACRO_char\*" "$OUTPUT_FILE"; then
    print_error "FAIL: Expected #define TEST_MACRO_char* not found"
    FAILED=1
fi

# Check 3: Output should contain processed variable replacements
if ! grep -q "Macro key: dap_list_t\*" "$OUTPUT_FILE"; then
    print_error "FAIL: Expected 'Macro key: dap_list_t*' not found"
    FAILED=1
fi

if ! grep -q "Base type: dap_list_t" "$OUTPUT_FILE"; then
    print_error "FAIL: Expected 'Base type: dap_list_t' not found"
    FAILED=1
fi

# Check 4: Output should not contain unprocessed variable markers
if grep -q "{{macro_key}}" "$OUTPUT_FILE"; then
    print_error "FAIL: Template contains unprocessed {{macro_key}}"
    FAILED=1
fi

if grep -q "{{base_type}}" "$OUTPUT_FILE"; then
    print_error "FAIL: Template contains unprocessed {{base_type}}"
    FAILED=1
fi

# Check 5: Output should contain all three entries
MACRO_COUNT=$(grep -c "#define TEST_MACRO_" "$OUTPUT_FILE" 2>/dev/null || echo "0")
if [ "$MACRO_COUNT" -ne 3 ]; then
    print_error "FAIL: Expected 3 macros, found $MACRO_COUNT"
    FAILED=1
fi

if [ $FAILED -eq 0 ]; then
    print_success "All checks passed!"
    exit 0
else
    print_error "Some checks failed"
    exit 1
fi

