// ============================================================================
// Type normalization macros
// ============================================================================
// These macros normalize pointer types by removing * from type names.

{{#if NORMALIZATION_MACROS_DATA}}
    {{#for entry in NORMALIZATION_MACROS_DATA}}
        {{entry|split|pipe}}
        {{#set macro_key={{entry|part|0}}}}
        {{#set base_type={{entry|part|1}}}}
        {{#set normalized_key={{entry|part|2}}}}
        {{#set escaped_base_key={{entry|part|3}}}}
        
        // Normalize type: {{escaped_base_key}} -> {{normalized_key}}
        #define _DAP_MOCK_NORMALIZE_TYPE_{{escaped_base_key}} {{normalized_key}}
    {{/for}}
{{/if}}

// ============================================================================
// Type-to-selector wrapper macros
// ============================================================================

{{#if TYPE_TO_SELECT_DATA}}
    {{#for entry in TYPE_TO_SELECT_DATA}}
        {{entry|split|pipe}}
        {{#set macro_key={{entry|part|0}}}}
        {{#set normalized_key={{entry|part|1}}}}
        {{#set selector_name={{entry|part|2}}}}
        
        // Type-to-selector wrapper for: {{normalized_key}} -> calls {{selector_name}}
        #define _DAP_MOCK_TYPE_TO_SELECT_NAME_{{normalized_key}}(func_name, return_type_full, ...) \
            {{selector_name}}(func_name, return_type_full, ##__VA_ARGS__)
    {{/for}}
{{/if}}

{{#set NORMALIZATION_MACROS_DATA={{AWK:
BEGIN {
    FS = "|"
    # Include AWK script functions
    @include "test-framework/mocks/lib/awk/prepare_normalization_data.awk"
}
# Process NORMALIZATION_RAW_DATA from environment
{
    if (NF == 2) {
        macro_key = $1
        base_type = $2
        if (macro_key == "" || base_type == "") next
        
        normalized_key = normalize_type(macro_key)
        escaped_base_key = escape_type(base_type)
        escaped_original_key = normalize_type(macro_key)
        escaped_macro_key_for_escape = escape_macro_key_for_escape(macro_key)
        escaped_macro_key_for_raw_type = escape_macro_key_for_raw_type(macro_key)
        
        print macro_key "|" base_type "|" normalized_key "|" escaped_base_key "|" escaped_original_key "|" escaped_macro_key_for_escape "|" escaped_macro_key_for_raw_type
    }
}
}}}}

{{#set TYPE_TO_SELECT_DATA={{AWK:
BEGIN {
    FS = "|"
    # Include AWK script functions
    @include "test-framework/mocks/lib/awk/prepare_type_to_select_data.awk"
}
# Process NORMALIZATION_RAW_DATA from environment
{
    if (NF == 2) {
        macro_key = $1
        base_type = $2
        if (macro_key == "" || base_type == "") next
        
        normalized_key = normalize_type(macro_key)
        selector_name = "_DAP_MOCK_WRAPPER_CUSTOM_SELECT_" normalized_key
        is_pointer = (macro_key ~ /\*/) ? "1" : "0"
        
        print macro_key "|" normalized_key "|" selector_name "|" is_pointer
    }
}
}}}}

{{#set BASIC_TYPES_DATA={{AWK:
BEGIN {
    FS = "|"
    # Include AWK script functions
    @include "test-framework/mocks/lib/awk/prepare_basic_types_data.awk"
}
# Process BASIC_TYPES_RAW_DATA from environment
{
    if (NF == 2) {
        basic_type = $1
        normalized_key = $2
        if (basic_type == "" || normalized_key == "") next
        
        escaped_base_key = escape_type(basic_type)
        selector_name = "_DAP_MOCK_WRAPPER_CUSTOM_SELECT_" normalized_key
        
        print basic_type "|" normalized_key "|" escaped_base_key "|" selector_name
    }
}
}}}}

// ============================================================================
// SELECT macros - route to void/non-void implementation
// ============================================================================

