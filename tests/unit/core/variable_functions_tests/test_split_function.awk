@include "core/variable_functions.awk"

BEGIN {
    # Test split by pipe
    ENVIRON["VAR"] = "a|b|c"
    process_split("VAR", "pipe", "a|b|c")
    test_result = ENVIRON["VAR_parts_0"] "|" ENVIRON["VAR_parts_1"] "|" ENVIRON["VAR_parts_2"] "|" ENVIRON["VAR_parts_count"]
    if (test_result != "a|b|c|3") {
        print "FAIL: split by pipe - Expected 'a|b|c|3', got '" test_result "'"
        exit 1
    }
    
    # Test split by space
    delete ENVIRON
    ENVIRON["VAR2"] = "int void char"
    process_split("VAR2", " ", "int void char")
    test_result = ENVIRON["VAR2_parts_0"] "|" ENVIRON["VAR2_parts_1"] "|" ENVIRON["VAR2_parts_2"] "|" ENVIRON["VAR2_parts_count"]
    if (test_result != "int|void|char|3") {
        print "FAIL: split by space - Expected 'int|void|char|3', got '" test_result "'"
        exit 1
    }
    
    # Test split by space keyword
    delete ENVIRON
    ENVIRON["VAR3"] = "one two three"
    process_split("VAR3", "space", "one two three")
    test_result = ENVIRON["VAR3_parts_0"] "|" ENVIRON["VAR3_parts_1"] "|" ENVIRON["VAR3_parts_2"] "|" ENVIRON["VAR3_parts_count"]
    if (test_result != "one|two|three|3") {
        print "FAIL: split by space keyword - Expected 'one|two|three|3', got '" test_result "'"
        exit 1
    }
    
    print "PASS"
}

