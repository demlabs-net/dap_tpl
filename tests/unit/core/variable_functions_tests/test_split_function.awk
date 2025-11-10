@include "core/variable_functions.awk"
BEGIN {
    ENVIRON["VAR"] = "a|b|c"
    result = process_split("VAR", "pipe", "a|b|c")
    part0 = ENVIRON["VAR_parts_0"]
    part1 = ENVIRON["VAR_parts_1"]
    part2 = ENVIRON["VAR_parts_2"]
    count = ENVIRON["VAR_parts_count"]
    test_result = part0 "|" part1 "|" part2 "|" count
    if (test_result != "a|b|c|3") {
        print "FAIL: Expected 'a|b|c|3', got '" test_result "'"
        exit 1
    }
    print "PASS"
}

