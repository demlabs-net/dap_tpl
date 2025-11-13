@include "core/variable_functions.awk"
BEGIN {
    # Test 1: Trim leading spaces
    result = process_trim("  test", "")
    if (result != "test") {
        print "FAIL: Test 1 - Expected 'test', got '" result "'"
        exit 1
    }
    
    # Test 2: Trim trailing spaces
    result = process_trim("test  ", "")
    if (result != "test") {
        print "FAIL: Test 2 - Expected 'test', got '" result "'"
        exit 1
    }
    
    # Test 3: Trim both sides
    result = process_trim("  test  ", "")
    if (result != "test") {
        print "FAIL: Test 3 - Expected 'test', got '" result "'"
        exit 1
    }
    
    # Test 4: Trim tabs
    result = process_trim("\ttest\t", "")
    if (result != "test") {
        print "FAIL: Test 4 - Expected 'test', got '" result "'"
        exit 1
    }
    
    # Test 5: No trimming needed
    result = process_trim("test", "")
    if (result != "test") {
        print "FAIL: Test 5 - Expected 'test', got '" result "'"
        exit 1
    }
    
    # Test 6: Only spaces (should return empty)
    result = process_trim("   ", "")
    if (result != "") {
        print "FAIL: Test 6 - Expected '', got '" result "'"
        exit 1
    }
    
    print "PASS"
}

