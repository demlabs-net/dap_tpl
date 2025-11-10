@include "core/variable_functions.awk"
BEGIN {
    result = process_ne("test", "other")
    if (result != "1") {
        print "FAIL: Expected '1', got '" result "'"
        exit 1
    }
    print "PASS"
}

