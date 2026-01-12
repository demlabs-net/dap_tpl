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
