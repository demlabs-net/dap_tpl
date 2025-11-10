@include "core/variable_functions.awk"
BEGIN {
    ENVIRON["LIST"] = "a|b|c"
    result = process_in_list("b", "LIST")
    if (result != "1") {
        print "FAIL: Expected '1', got '" result "'"
        exit 1
    }
    print "PASS"
}

