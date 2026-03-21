@include "core/variable_functions.awk"
BEGIN {
    list = "aa|bb|cc|dd|ee"

    # Test 1: Literal integer index
    result = process_at(list, "0")
    if (result != "aa") {
        print "FAIL: Test 1 - Expected 'aa', got '" result "'"
        exit 1
    }

    # Test 2: Last element
    result = process_at(list, "4")
    if (result != "ee") {
        print "FAIL: Test 2 - Expected 'ee', got '" result "'"
        exit 1
    }

    # Test 3: Variable name as index
    ENVIRON["idx"] = "2"
    result = process_at(list, "idx")
    if (result != "cc") {
        print "FAIL: Test 3 - Expected 'cc', got '" result "'"
        exit 1
    }

    # Test 4: Arithmetic expression as index
    ENVIRON["x"] = "1"
    result = process_at(list, "x+2")
    if (result != "dd") {
        print "FAIL: Test 4 - Expected 'dd', got '" result "'"
        exit 1
    }

    # Test 5: Out-of-range returns empty
    result = process_at(list, "99")
    if (result != "") {
        print "FAIL: Test 5 - Expected '', got '" result "'"
        exit 1
    }

    # Test 6: Numeric list
    nlist = "10|20|30|40|50"
    result = process_at(nlist, "3")
    if (result != "40") {
        print "FAIL: Test 6 - Expected '40', got '" result "'"
        exit 1
    }

    # Test 7: Expression with modulo
    ENVIRON["n"] = "7"
    result = process_at(list, "n%5")
    if (result != "cc") {
        print "FAIL: Test 7 - Expected 'cc', got '" result "'"
        exit 1
    }

    print "PASS"
}
