# Test empty array handling in for construct
# Tests that empty arrays are handled gracefully with warning

@include "constructs/modules/for_construct.awk"
@include "constructs/modules/nested_constructs.awk"

BEGIN {
    # Test 1: Empty array in ENVIRON
    # Note: Empty arrays trigger a warning but return empty string
    ENVIRON["EMPTY_LIST"] = ""
    condition = "item in EMPTY_LIST"
    content = "Item: {{item}}\n"
    
    result = process_for_construct(condition, content, 0)
    
    # Should return empty string (no items to process, warning is printed to stderr)
    if (result != "") {
        print "FAIL: Expected empty result for empty array, got: " substr(result, 1, 100)
        exit 1
    }
    
    # Test 2: Array with only empty strings
    ENVIRON["EMPTY_ITEMS"] = "||"
    condition2 = "item in EMPTY_ITEMS"
    result2 = process_for_construct(condition2, content, 0)
    
    # Should return empty string (empty items are skipped)
    if (result2 != "") {
        print "FAIL: Expected empty result for array with empty items, got: " substr(result2, 1, 100)
        exit 1
    }
    
    # Test 3: Non-empty array should work
    ENVIRON["NON_EMPTY_LIST"] = "item1|item2"
    condition3 = "item in NON_EMPTY_LIST"
    result3 = process_for_construct(condition3, content, 0)
    
    if (result3 == "") {
        print "FAIL: Expected non-empty result for non-empty array"
        exit 1
    }
    if (result3 !~ /Item: item1/) {
        print "FAIL: Expected 'Item: item1' in result"
        exit 1
    }
    if (result3 !~ /Item: item2/) {
        print "FAIL: Expected 'Item: item2' in result"
        exit 1
    }
    
    print "PASS"
}

