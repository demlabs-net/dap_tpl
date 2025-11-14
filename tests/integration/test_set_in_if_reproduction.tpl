{{#if RETURN_TYPES}}
    {{#set SELECT_MACROS_DATA={{AWK:
BEGIN {
    print "value1|value2"
}
}}
    }}
    
    {{#set NORMALIZATION_MACROS_DATA={{AWK:
BEGIN {
    FS = "|"
    print "int*|int"
}
}}}}
{{/if}}

// Some C code

