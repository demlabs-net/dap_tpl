@include "core/macro_store.awk"
BEGIN {
    # Test 1: Store and retrieve macro
    store_macro("TEST_MACRO", "Hello {{ARG0}}")
    if (!is_macro_defined("TEST_MACRO")) {
        print "FAIL: Test 1 - Macro should be defined"
        exit 1
    }
    content = get_macro("TEST_MACRO")
    if (content != "Hello {{ARG0}}") {
        print "FAIL: Test 1 - Expected 'Hello {{ARG0}}', got '" content "'"
        exit 1
    }
    
    # Test 2: Check undefined macro
    if (is_macro_defined("UNDEFINED")) {
        print "FAIL: Test 2 - Macro should not be defined"
        exit 1
    }
    content = get_macro("UNDEFINED")
    if (content != "") {
        print "FAIL: Test 2 - Expected '', got '" content "'"
        exit 1
    }
    
    # Test 3: Expand macro with parameters
    store_macro("GREETING", "Hello {{ARG0}}, welcome to {{ARG1}}")
    params[0] = "World"
    params[1] = "DAP TPL"
    expanded = expand_macro("GREETING", 2, params)
    if (expanded != "Hello World, welcome to DAP TPL") {
        print "FAIL: Test 3 - Expected 'Hello World, welcome to DAP TPL', got '" expanded "'"
        exit 1
    }
    
    # Test 4: Expand macro with single parameter
    store_macro("SIMPLE", "Value: {{ARG0}}")
    params[0] = "test"
    expanded = expand_macro("SIMPLE", 1, params)
    if (expanded != "Value: test") {
        print "FAIL: Test 4 - Expected 'Value: test', got '" expanded "'"
        exit 1
    }
    
    # Test 5: Expand macro with no parameters
    store_macro("NO_PARAMS", "Static content")
    expanded = expand_macro("NO_PARAMS", 0, params)
    if (expanded != "Static content") {
        print "FAIL: Test 5 - Expected 'Static content', got '" expanded "'"
        exit 1
    }
    
    # Test 6: Expand undefined macro
    expanded = expand_macro("UNDEFINED", 0, params)
    if (expanded != "") {
        print "FAIL: Test 6 - Expected '', got '" expanded "'"
        exit 1
    }
    
    print "PASS"
}

