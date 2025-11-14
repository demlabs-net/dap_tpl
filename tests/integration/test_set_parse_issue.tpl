Before if
{{#if RETURN_TYPES}}
Inner text
{{#set NORMALIZATION_MACROS_DATA={{AWK:
BEGIN {
    print "data"
}
}}}}
After set
{{/if}}
After if

