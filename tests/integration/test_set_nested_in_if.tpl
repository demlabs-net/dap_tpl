{{#if RETURN_TYPES}}
    {{#set SELECT_MACROS_DATA={{AWK:
BEGIN {
    print "value1"
}
}}
    }}
    
    {{#set NORMALIZATION_MACROS_DATA={{AWK:
BEGIN {
    print "value2"
}
}}}}
    
    {{#set TYPE_TO_SELECT_DATA={{AWK:
BEGIN {
    print "value3"
}
}}}}
{{/if}}

Result: done

