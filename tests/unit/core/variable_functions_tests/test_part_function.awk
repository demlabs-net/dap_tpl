@include "core/variable_functions.awk"
BEGIN {
    ENVIRON["VAR_parts_0"] = "a"
    ENVIRON["VAR_parts_1"] = "b"
    ENVIRON["VAR_parts_2"] = "c"
    result = process_part("VAR", "1")
    if (result != "b") {
        print "FAIL: Expected 'b', got '" result "'"
        exit 1
    }
    print "PASS"
}

