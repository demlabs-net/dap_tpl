@include "core/variable_functions.awk"
BEGIN {
    # Test 1: Simple addition with $
    result = process_math("3", "$+10")
    if (result != "13") {
        print "FAIL: Test 1 - Expected '13', got '" result "'"
        exit 1
    }

    # Test 2: Modulo
    result = process_math("7", "$%5")
    if (result != "2") {
        print "FAIL: Test 2 - Expected '2', got '" result "'"
        exit 1
    }

    # Test 3: Compound expression
    result = process_math("3", "($+1)%5")
    if (result != "4") {
        print "FAIL: Test 3 - Expected '4', got '" result "'"
        exit 1
    }

    # Test 4: Multiplication
    result = process_math("8", "$*3")
    if (result != "24") {
        print "FAIL: Test 4 - Expected '24', got '" result "'"
        exit 1
    }

    # Test 5: Variable reference in expression
    ENVIRON["y"] = "5"
    result = process_math("2", "$+y")
    if (result != "7") {
        print "FAIL: Test 5 - Expected '7', got '" result "'"
        exit 1
    }

    # Test 6: Complex expression with multiple vars
    ENVIRON["a"] = "10"
    ENVIRON["b"] = "3"
    result = process_math("0", "a+b")
    if (result != "13") {
        print "FAIL: Test 6 - Expected '13', got '" result "'"
        exit 1
    }

    # Test 7: Negative result
    result = process_math("2", "$-5")
    if (result != "-3") {
        print "FAIL: Test 7 - Expected '-3', got '" result "'"
        exit 1
    }

    print "PASS"
}
