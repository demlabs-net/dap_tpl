@include "core/variable_functions.awk"

function test_split_by_pipe() {
    ENVIRON["VAR"] = "a|b|c"
    result = process_split("VAR", "pipe", "a|b|c")
    part0 = ENVIRON["VAR_parts_0"]
    part1 = ENVIRON["VAR_parts_1"]
    part2 = ENVIRON["VAR_parts_2"]
    count = ENVIRON["VAR_parts_count"]
    test_result = part0 "|" part1 "|" part2 "|" count
    if (test_result != "a|b|c|3") {
        print "FAIL test_split_by_pipe: Expected 'a|b|c|3', got '" test_result "'"
        exit 1
    }
    print "PASS test_split_by_pipe"
}

function test_split_by_space() {
    delete ENVIRON
    ENVIRON["VAR2"] = "int void char"
    result = process_split("VAR2", " ", "int void char")
    part0 = ENVIRON["VAR2_parts_0"]
    part1 = ENVIRON["VAR2_parts_1"]
    part2 = ENVIRON["VAR2_parts_2"]
    count = ENVIRON["VAR2_parts_count"]
    
    test_result = part0 "|" part1 "|" part2 "|" count
    if (test_result != "int|void|char|3") {
        print "FAIL test_split_by_space: Expected 'int|void|char|3', got '" test_result "'"
        exit 1
    }
    print "PASS test_split_by_space"
}

function test_split_by_space_keyword() {
    delete ENVIRON
    ENVIRON["VAR3"] = "one two three"
    result = process_split("VAR3", "space", "one two three")
    part0 = ENVIRON["VAR3_parts_0"]
    part1 = ENVIRON["VAR3_parts_1"]
    part2 = ENVIRON["VAR3_parts_2"]
    count = ENVIRON["VAR3_parts_count"]
    test_result = part0 "|" part1 "|" part2 "|" count
    if (test_result != "one|two|three|3") {
        print "FAIL test_split_by_space_keyword: Expected 'one|two|three|3', got '" test_result "'"
        exit 1
    }
    print "PASS test_split_by_space_keyword"
}

BEGIN {
    test_split_by_pipe()
    test_split_by_space()
    test_split_by_space_keyword()
    print "All split tests passed"
}

