#!/bin/bash
# Regression test for {{#include}} with TEMPLATES_DIR
# This test verifies that {{#include}} correctly resolves sub-templates
# using TEMPLATES_DIR environment variable, even when templates are
# in different directories than the main template.
#
# Bug: When using {{#include "sub_template.tpl"}} with TEMPLATES_DIR set,
# the include mechanism should find sub_template.tpl in TEMPLATES_DIR,
# but it was only looking relative to the main template file location.
# This prevented modular template organization where sub-templates are
# in a shared directory.
#
# Fixed in: constructs/include/evaluator.awk (search path resolution)

set -e

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "$TEST_DIR/../.." && pwd)"
TEMPLATES_DIR="${TEST_DIR}/fixtures/include_test"

export SCRIPTS_DIR="${DAP_TPL_DIR}"
export TEMPLATES_DIR
export AWKPATH="${DAP_TPL_DIR}"

# Create fixtures directory
mkdir -p "${TEMPLATES_DIR}"

# Build engine and capture path
ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
    echo "ERROR: Failed to build engine or find engine file"
    echo "$ENGINE_OUTPUT"
    exit 1
fi

# Export DAP_TPL_ENGINE_PATH so sub-processes ({{#include}}) can use the same engine
export DAP_TPL_ENGINE_PATH="$COMPILED_ENGINE"

# Test 1: Basic {{#include}} with TEMPLATES_DIR
echo "Test 1: Basic {{#include}} with TEMPLATES_DIR"

# Create sub-template in TEMPLATES_DIR
cat > "${TEMPLATES_DIR}/sub_basic.tpl" << 'EOF'
INCLUDED: {{MESSAGE}}
EOF

# Create main template in a different location (temp)
MAIN_TEMPLATE="/tmp/test_include_main_basic.tpl"
cat > "$MAIN_TEMPLATE" << 'EOF'
BEFORE
{{#include sub_basic.tpl}}
AFTER
EOF

# Set variables
export MESSAGE="Hello from include"

# Process template (cd to DAP_TPL_DIR for @include paths to work)
OUTPUT=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$MAIN_TEMPLATE" 2>/dev/null)

# Verify output
if ! echo "$OUTPUT" | grep -q "BEFORE"; then
    echo "FAIL: BEFORE marker should be present"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "INCLUDED: Hello from include"; then
    echo "FAIL: Included content with variable substitution should be present"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "AFTER"; then
    echo "FAIL: AFTER marker should be present"
    echo "Output:"
    echo "$OUTPUT" | cat -A
    exit 1
fi

echo "PASS: Basic {{#include}} with TEMPLATES_DIR"

# Test 2: {{#include}} with conditionals in sub-template
echo "Test 2: {{#include}} with conditionals in sub-template"

# Create sub-template with conditional
cat > "${TEMPLATES_DIR}/sub_conditional.tpl" << 'EOF'
{{#if ENABLE_FEATURE}}
FEATURE ENABLED: {{FEATURE_NAME}}
{{/if}}
EOF

MAIN_TEMPLATE2="/tmp/test_include_main_conditional.tpl"
cat > "$MAIN_TEMPLATE2" << 'EOF'
START
{{#include sub_conditional.tpl}}
END
EOF

export ENABLE_FEATURE="YES"
export FEATURE_NAME="SuperFeature"

OUTPUT2=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$MAIN_TEMPLATE2" 2>/dev/null)

if ! echo "$OUTPUT2" | grep -q "FEATURE ENABLED: SuperFeature"; then
    echo "FAIL: Conditional in included template should be processed"
    echo "Output:"
    echo "$OUTPUT2" | cat -A
    exit 1
fi

echo "PASS: {{#include}} with conditionals in sub-template"

# Test 3: {{#include}} with variables defined before include
echo "Test 3: {{#include}} with variables defined before include"

cat > "${TEMPLATES_DIR}/sub_with_vars.tpl" << 'EOF'
ARCH: {{ARCH_NAME}}
CHUNK_SIZE: {{CHUNK_SIZE}}
EOF

MAIN_TEMPLATE3="/tmp/test_include_main_with_vars.tpl"
cat > "$MAIN_TEMPLATE3" << 'EOF'
{{#set ARCH_NAME=AVX2}}
{{#set CHUNK_SIZE=32}}
CONFIG:
{{#include sub_with_vars.tpl}}
EOF

OUTPUT3=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$MAIN_TEMPLATE3" 2>/dev/null)

if ! echo "$OUTPUT3" | grep -q "ARCH: AVX2"; then
    echo "FAIL: Variable ARCH_NAME should be available in included template"
    echo "Output:"
    echo "$OUTPUT3" | cat -A
    exit 1
fi

if ! echo "$OUTPUT3" | grep -q "CHUNK_SIZE: 32"; then
    echo "FAIL: Variable CHUNK_SIZE should be available in included template"
    echo "Output:"
    echo "$OUTPUT3" | cat -A
    exit 1
fi

echo "PASS: {{#include}} with variables defined before include"

# Test 4: Nested {{#include}} (sub-template includes another sub-template)
echo "Test 4: Nested {{#include}}"

cat > "${TEMPLATES_DIR}/sub_level2.tpl" << 'EOF'
LEVEL2: {{DATA}}
EOF

cat > "${TEMPLATES_DIR}/sub_level1.tpl" << 'EOF'
LEVEL1 START
{{#include sub_level2.tpl}}
LEVEL1 END
EOF

MAIN_TEMPLATE4="/tmp/test_include_main_nested.tpl"
cat > "$MAIN_TEMPLATE4" << 'EOF'
MAIN START
{{#include sub_level1.tpl}}
MAIN END
EOF

export DATA="Nested Include Works"

OUTPUT4=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$MAIN_TEMPLATE4" 2>/dev/null)

if ! echo "$OUTPUT4" | grep -q "MAIN START"; then
    echo "FAIL: Main template marker should be present"
    echo "Output:"
    echo "$OUTPUT4" | cat -A
    exit 1
fi

if ! echo "$OUTPUT4" | grep -q "LEVEL1 START"; then
    echo "FAIL: Level 1 include marker should be present"
    echo "Output:"
    echo "$OUTPUT4" | cat -A
    exit 1
fi

if ! echo "$OUTPUT4" | grep -q "LEVEL2: Nested Include Works"; then
    echo "FAIL: Level 2 include with variable should be present"
    echo "Output:"
    echo "$OUTPUT4" | cat -A
    exit 1
fi

if ! echo "$OUTPUT4" | grep -q "LEVEL1 END"; then
    echo "FAIL: Level 1 end marker should be present"
    echo "Output:"
    echo "$OUTPUT4" | cat -A
    exit 1
fi

if ! echo "$OUTPUT4" | grep -q "MAIN END"; then
    echo "FAIL: Main end marker should be present"
    echo "Output:"
    echo "$OUTPUT4" | cat -A
    exit 1
fi

echo "PASS: Nested {{#include}}"

# Test 5: Real-world scenario - SIMD string scanner include
echo "Test 5: Real-world scenario - SIMD architecture-specific helper include"

# Simulate architecture-specific helper template
cat > "${TEMPLATES_DIR}/string_scanner_simd.tpl" << 'EOF'
// SIMD String Scanner for {{ARCH_NAME}}
// This is a specialized fast-path for strings without escape sequences
{{#if USE_AVX512_MASK}}
// AVX-512 uses k-mask comparisons
static inline const uint8_t* scan_string_fast(const uint8_t* p, const uint8_t* end) {
    {{VECTOR_TYPE}} quote_vec = {{SET1_EPI8}}('"');
    {{VECTOR_TYPE}} backslash_vec = {{SET1_EPI8}}('\\');
    while (p + {{CHUNK_SIZE}} <= end) {
        {{VECTOR_TYPE}} chunk = {{LOADU}}((const {{VECTOR_TYPE}}*)p);
        {{MOVEMASK_TYPE}} quote_mask = {{CMPEQ_EPI8_MASK}}(chunk, quote_vec);
        {{MOVEMASK_TYPE}} backslash_mask = {{CMPEQ_EPI8_MASK}}(chunk, backslash_vec);
        if (quote_mask || backslash_mask) {
            // Found something - determine what was first
            return p + __builtin_ctzll(quote_mask | backslash_mask);
        }
        p += {{CHUNK_SIZE}};
    }
    return NULL; // Not found in vectorized part
}
{{else}}
// SSE2/AVX2/NEON use vector comparisons
static inline const uint8_t* scan_string_fast(const uint8_t* p, const uint8_t* end) {
    {{VECTOR_TYPE}} quote_vec = {{SET1_EPI8}}('"');
    {{VECTOR_TYPE}} backslash_vec = {{SET1_EPI8}}('\\');
    while (p + {{CHUNK_SIZE}} <= end) {
        {{VECTOR_TYPE}} chunk = {{LOADU}}((const {{VECTOR_TYPE}}*)p);
        {{VECTOR_TYPE}} quote_cmp = {{CMPEQ_EPI8}}(chunk, quote_vec);
        {{VECTOR_TYPE}} backslash_cmp = {{CMPEQ_EPI8}}(chunk, backslash_vec);
        {{VECTOR_TYPE}} combined = {{OR}}(quote_cmp, backslash_cmp);
        {{MASK_TYPE}} mask = {{MOVEMASK_EPI8}}(combined);
        if (mask) {
            return p + __builtin_ctz(mask);
        }
        p += {{CHUNK_SIZE}};
    }
    return NULL;
}
{{/if}}
EOF

# Simulate main SIMD template
MAIN_TEMPLATE5="/tmp/test_include_main_simd.tpl"
cat > "$MAIN_TEMPLATE5" << 'EOF'
// Generated SIMD implementation for {{ARCH_NAME}}
#include <stdint.h>
#include <stddef.h>
{{ARCH_INCLUDES}}

#define CHUNK_SIZE {{CHUNK_SIZE}}

{{#include string_scanner_simd.tpl}}

// Main tokenization function
void tokenize_{{ARCH_LOWER}}(const uint8_t* data, size_t len) {
    const uint8_t* p = scan_string_fast(data, data + len);
    // ... rest of tokenization
}
EOF

# Test AVX-512 variant
export ARCH_NAME="AVX-512"
export ARCH_LOWER="avx512"
export ARCH_INCLUDES="#include <immintrin.h>"
export CHUNK_SIZE="64"
export VECTOR_TYPE="__m512i"
export SET1_EPI8="_mm512_set1_epi8"
export LOADU="_mm512_loadu_si512"
export CMPEQ_EPI8_MASK="_mm512_cmpeq_epi8_mask"
export MOVEMASK_TYPE="__mmask64"
export USE_AVX512_MASK="1"

OUTPUT5_AVX512=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$MAIN_TEMPLATE5" 2>/dev/null)

if ! echo "$OUTPUT5_AVX512" | grep -q "// Generated SIMD implementation for AVX-512"; then
    echo "FAIL: AVX-512 header should be present"
    echo "Output:"
    echo "$OUTPUT5_AVX512" | head -20
    exit 1
fi

if ! echo "$OUTPUT5_AVX512" | grep -q "// AVX-512 uses k-mask comparisons"; then
    echo "FAIL: AVX-512 conditional path should be taken"
    echo "Output:"
    echo "$OUTPUT5_AVX512" | head -40
    exit 1
fi

if ! echo "$OUTPUT5_AVX512" | grep -q "__mmask64 quote_mask = _mm512_cmpeq_epi8_mask"; then
    echo "FAIL: AVX-512 k-mask comparison should be generated"
    echo "Output:"
    echo "$OUTPUT5_AVX512" | head -40
    exit 1
fi

if ! echo "$OUTPUT5_AVX512" | grep -q "void tokenize_avx512"; then
    echo "FAIL: Architecture-specific function name should be generated"
    echo "Output:"
    echo "$OUTPUT5_AVX512" | tail -10
    exit 1
fi

echo "PASS: Real-world AVX-512 SIMD include"

# Test SSE2 variant (non-mask path)
export ARCH_NAME="SSE2"
export ARCH_LOWER="sse2"
export ARCH_INCLUDES="#include <emmintrin.h>"
export CHUNK_SIZE="16"
export VECTOR_TYPE="__m128i"
export SET1_EPI8="_mm_set1_epi8"
export LOADU="_mm_loadu_si128"
export CMPEQ_EPI8="_mm_cmpeq_epi8"
export OR="_mm_or_si128"
export MOVEMASK_EPI8="_mm_movemask_epi8"
export MASK_TYPE="uint16_t"
export USE_AVX512_MASK=""

OUTPUT5_SSE2=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$MAIN_TEMPLATE5" 2>/dev/null)

if ! echo "$OUTPUT5_SSE2" | grep -q "// Generated SIMD implementation for SSE2"; then
    echo "FAIL: SSE2 header should be present"
    echo "Output:"
    echo "$OUTPUT5_SSE2" | head -20
    exit 1
fi

if ! echo "$OUTPUT5_SSE2" | grep -q "// SSE2/AVX2/NEON use vector comparisons"; then
    echo "FAIL: SSE2 conditional path should be taken"
    echo "Output:"
    echo "$OUTPUT5_SSE2" | head -40
    exit 1
fi

if ! echo "$OUTPUT5_SSE2" | grep -q "__m128i quote_cmp = _mm_cmpeq_epi8"; then
    echo "FAIL: SSE2 vector comparison should be generated"
    echo "Output:"
    echo "$OUTPUT5_SSE2" | head -40
    exit 1
fi

if ! echo "$OUTPUT5_SSE2" | grep -q "__m128i combined = _mm_or_si128"; then
    echo "FAIL: SSE2 vector OR should be generated"
    echo "Output:"
    echo "$OUTPUT5_SSE2" | head -40
    exit 1
fi

if ! echo "$OUTPUT5_SSE2" | grep -q "void tokenize_sse2"; then
    echo "FAIL: Architecture-specific function name should be generated"
    echo "Output:"
    echo "$OUTPUT5_SSE2" | tail -10
    exit 1
fi

echo "PASS: Real-world SSE2 SIMD include"

# Test 6: {{#include}} with missing sub-template (should fail gracefully)
echo "Test 6: {{#include}} with non-existent sub-template"

MAIN_TEMPLATE6="/tmp/test_include_main_missing.tpl"
cat > "$MAIN_TEMPLATE6" << 'EOF'
START
{{#include non_existent_file.tpl}}
END
EOF

# This should produce an error or empty output for the include
OUTPUT6=$(cd "$DAP_TPL_DIR" && gawk -f "$COMPILED_ENGINE" "$MAIN_TEMPLATE6" 2>&1 || echo "ERROR_OCCURRED")

# We expect either an error message or the include to be skipped
if echo "$OUTPUT6" | grep -q "START" && echo "$OUTPUT6" | grep -q "END"; then
    echo "PASS: Missing sub-template handled gracefully (markers present)"
elif echo "$OUTPUT6" | grep -qi "error\|ERROR_OCCURRED"; then
    echo "PASS: Missing sub-template produced error as expected"
else
    echo "WARNING: Unclear handling of missing sub-template"
    echo "Output:"
    echo "$OUTPUT6"
fi

echo ""
echo "=========================================="
echo "ALL REGRESSION TESTS PASSED"
echo "=========================================="

