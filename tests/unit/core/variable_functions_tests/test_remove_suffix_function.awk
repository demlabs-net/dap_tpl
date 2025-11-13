@include "core/variable_functions.awk"
BEGIN {
    # Test 1: Remove _PTR suffix
    result = process_remove_suffix("dap_list_t_PTR", "_PTR")
    if (result != "dap_list_t") {
        print "FAIL: Test 1 - Expected 'dap_list_t', got '" result "'"
        exit 1
    }
    
    # Test 2: Remove _STAR suffix
    result = process_remove_suffix("type_STAR", "_STAR")
    if (result != "type") {
        print "FAIL: Test 2 - Expected 'type', got '" result "'"
        exit 1
    }
    
    # Test 3: No suffix (should return unchanged)
    result = process_remove_suffix("simple_name", "_PTR")
    if (result != "simple_name") {
        print "FAIL: Test 3 - Expected 'simple_name', got '" result "'"
        exit 1
    }
    
    # Test 4: Suffix in middle (should not remove)
    result = process_remove_suffix("test_PTR_name", "_PTR")
    if (result != "test_PTR_name") {
        print "FAIL: Test 4 - Expected 'test_PTR_name', got '" result "'"
        exit 1
    }
    
    # Test 5: Empty suffix
    result = process_remove_suffix("test_name", "")
    if (result != "test_name") {
        print "FAIL: Test 5 - Expected 'test_name', got '" result "'"
        exit 1
    }
    
    print "PASS"
}

