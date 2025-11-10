# Test if construct with else processing
# Tests {{#if VAR}} ... {{else}} ... {{/if}}

@include "constructs/modules/if_construct.awk"

BEGIN {
    # Test 1: Condition is true - should return content
    ENVIRON["TEST_VAR"] = "value"
    condition = "TEST_VAR"
    content = "Content when true\n"
    else_content = "Content when false\n"
    
    result = process_if_construct(condition, content, else_content, 0)
    if (result != content) {
        print "FAIL: Expected content when condition is true"
        exit 1
    }
    
    # Test 2: Condition is false - should return else_content
    delete ENVIRON["TEST_VAR"]
    result = process_if_construct(condition, content, else_content, 0)
    if (result != else_content) {
        print "FAIL: Expected else_content when condition is false"
        exit 1
    }
    
    # Test 3: Condition is false, no else - should return empty
    result = process_if_construct(condition, content, "", 0)
    if (result != "") {
        print "FAIL: Expected empty result when condition is false and no else"
        exit 1
    }
    
    # Test 4: Condition with function - contains
    ENVIRON["TEST_VAR"] = "test_value"
    condition2 = "TEST_VAR|contains|test"
    result = process_if_construct(condition2, content, else_content, 0)
    if (result != content) {
        print "FAIL: Expected content when contains() returns true"
        exit 1
    }
    
    # Test 5: Condition with function - contains (false)
    condition3 = "TEST_VAR|contains|notfound"
    result = process_if_construct(condition3, content, else_content, 0)
    if (result != else_content) {
        print "FAIL: Expected else_content when contains() returns false"
        exit 1
    }
    
    print "PASS"
}

