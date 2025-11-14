{{#set SOME_VAR={{AWK:
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

Some text after

