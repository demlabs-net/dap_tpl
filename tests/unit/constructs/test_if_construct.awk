# Test if construct processing
# Tests {{#if VAR}} ... {{/if}}

@include "constructs/modules/if_construct.awk"

BEGIN {
    # Test 1: Variable exists and is non-empty
    ENVIRON["TEST_VAR"] = "value"
    condition = "TEST_VAR"
    content = "Content when true\n"
    result = process_if_construct(condition, content, "", 0)
    if (result != content) {
        print "FAIL: Expected content when variable is set"
        exit 1
    }
    
    # Test 2: Variable is empty
    delete ENVIRON["TEST_VAR"]
    result = process_if_construct(condition, content, "", 0)
    if (result != "") {
        print "FAIL: Expected empty result when variable is unset"
        exit 1
    }
    
    # Test 3: Variable is "0"
    ENVIRON["TEST_VAR"] = "0"
    result = process_if_construct(condition, content, "", 0)
    if (result != "") {
        print "FAIL: Expected empty result when variable is '0'"
        exit 1
    }
    
    # Test 4: With else content
    ENVIRON["TEST_VAR"] = ""
    else_content = "Content when false\n"
    result = process_if_construct(condition, content, else_content, 0)
    if (result != else_content) {
        print "FAIL: Expected else content when condition is false"
        exit 1
    }
    
    print "PASS"
}

