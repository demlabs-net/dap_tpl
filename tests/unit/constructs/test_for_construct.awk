# Test for construct processing
# Tests {{#for item in LIST}} ... {{/for}}

@include "constructs/modules/for_construct.awk"
@include "core/variable_replacer.awk"
@include "constructs/modules/nested_constructs.awk"
@include "constructs/modules/awk_sections.awk"

BEGIN {
    # Set up test environment
    ENVIRON["TEST_LIST"] = "item1|item2|item3"
    
    # Test for construct processing
    condition = "item in TEST_LIST"
    content = "Value: {{item}}\n"
    recursion_depth = 0
    
    # Process construct using function
    result = process_for_construct(condition, content, recursion_depth)
    
    # Verify result contains all three items
    if (result !~ /Value: item1/) {
        print "FAIL: Expected 'Value: item1' in result"
        exit 1
    }
    if (result !~ /Value: item2/) {
        print "FAIL: Expected 'Value: item2' in result"
        exit 1
    }
    if (result !~ /Value: item3/) {
        print "FAIL: Expected 'Value: item3' in result"
        exit 1
    }
    
    print "PASS"
}

