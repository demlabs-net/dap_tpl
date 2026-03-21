@include "core/variable_functions.awk"
BEGIN {
    ENVIRON["MAP_0"] = "alpha"
    ENVIRON["MAP_1"] = "beta"
    ENVIRON["MAP_2"] = "gamma"
    ENVIRON["color_red"] = "#ff0000"

    # Test 1: Resolve with prefix
    result = process_resolve("1", "MAP_")
    if (result != "beta") {
        print "FAIL: Test 1 - Expected 'beta', got '" result "'"
        exit 1
    }

    # Test 2: Resolve with prefix (index 0)
    result = process_resolve("0", "MAP_")
    if (result != "alpha") {
        print "FAIL: Test 2 - Expected 'alpha', got '" result "'"
        exit 1
    }

    # Test 3: Resolve without prefix (indirect)
    ENVIRON["myvar"] = "hello"
    result = process_resolve("myvar", "")
    if (result != "hello") {
        print "FAIL: Test 3 - Expected 'hello', got '" result "'"
        exit 1
    }

    # Test 4: Resolve with prefix containing underscore
    result = process_resolve("red", "color_")
    if (result != "#ff0000") {
        print "FAIL: Test 4 - Expected '#ff0000', got '" result "'"
        exit 1
    }

    # Test 5: Non-existent variable returns empty
    result = process_resolve("99", "MAP_")
    if (result != "") {
        print "FAIL: Test 5 - Expected '', got '" result "'"
        exit 1
    }

    print "PASS"
}
