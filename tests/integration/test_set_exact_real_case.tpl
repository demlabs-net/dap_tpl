{{#set SOME_DATA={{AWK:
BEGIN {
    print "value1|value2"
}
}}}}
    }}

    {{#set NORMALIZATION_MACROS_DATA={{AWK:
BEGIN {
    FS = "|"
    print "int*|int"
}
}}}}

// Some C code

