{{#set TEST_VAR={{AWK:
BEGIN {
    print "test_output"
}
}}}}
Value: {{TEST_VAR}}

{{#set NORMALIZATION_MACROS_DATA={{AWK:
BEGIN {
    print "data1|data2"
}
}}}}
Data: {{NORMALIZATION_MACROS_DATA}}

