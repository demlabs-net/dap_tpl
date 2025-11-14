// Some C code before
int some_function() {
    return 0;
}

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

// Some C code after

