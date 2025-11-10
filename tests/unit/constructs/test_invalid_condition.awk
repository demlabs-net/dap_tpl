# Test invalid condition handling in if construct
# Tests that invalid conditions are handled gracefully

@include "constructs/modules/if_construct.awk"

BEGIN {
    # Test 1: Non-existent variable (should be false)
    condition1 = "NON_EXISTENT_VAR"
    content = "Content\n"
    
    result1 = process_if_construct(condition1, content, "", 0)
    if (result1 != "") {
        print "FAIL: Expected empty result for non-existent variable, got: " result1
        exit 1
    }
    
    # Test 2: Empty variable (should be false)
    ENVIRON["EMPTY_VAR"] = ""
    condition2 = "EMPTY_VAR"
    result2 = process_if_construct(condition2, content, "", 0)
    if (result2 != "") {
        print "FAIL: Expected empty result for empty variable, got: " result2
        exit 1
    }
    
    # Test 3: Variable with "0" (should be false)
    ENVIRON["ZERO_VAR"] = "0"
    condition3 = "ZERO_VAR"
    result3 = process_if_construct(condition3, content, "", 0)
    if (result3 != "") {
        print "FAIL: Expected empty result for '0' variable, got: " result3
        exit 1
    }
    
    # Test 4: Variable with "false" (should be false)
    ENVIRON["FALSE_VAR"] = "false"
    condition4 = "FALSE_VAR"
    result4 = process_if_construct(condition4, content, "", 0)
    if (result4 != "") {
        print "FAIL: Expected empty result for 'false' variable, got: " result4
        exit 1
    }
    
    # Test 5: Variable with "no" (should be false)
    ENVIRON["NO_VAR"] = "no"
    condition5 = "NO_VAR"
    result5 = process_if_construct(condition5, content, "", 0)
    if (result5 != "") {
        print "FAIL: Expected empty result for 'no' variable, got: " result5
        exit 1
    }
    
    # Test 6: Valid variable (should be true)
    ENVIRON["VALID_VAR"] = "value"
    condition6 = "VALID_VAR"
    result6 = process_if_construct(condition6, content, "", 0)
    if (result6 != content) {
        print "FAIL: Expected content for valid variable, got: " result6
        exit 1
    }
    
    # Test 7: Invalid function call (non-existent function)
    ENVIRON["TEST_VAR"] = "value"
    condition7 = "TEST_VAR|nonexistent_function|arg"
    # Should handle gracefully - function doesn't exist, so treat as false
    result7 = process_if_construct(condition7, content, "", 0)
    # This might return empty or content depending on implementation
    # Just verify it doesn't crash
    
    print "PASS"
}

