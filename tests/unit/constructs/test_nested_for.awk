# Test nested for constructs
# Tests {{#for outer in OUTER_LIST}} {{#for inner in INNER_LIST}} ... {{/for}} {{/for}}

@include "constructs/modules/for_construct.awk"
@include "core/variable_replacer.awk"
@include "constructs/modules/nested_constructs.awk"
@include "constructs/modules/awk_sections.awk"

BEGIN {
    ENVIRON["OUTER_LIST"] = "outer1|outer2"
    ENVIRON["INNER_LIST"] = "inner1|inner2"
    
    # Test nested for loops
    # Outer loop content contains inner loop
    # Note: process_nested_constructs expects constructs to be properly formatted
    # We'll test with a simpler approach - verify that outer loop works and processes content
    outer_content = "Outer: {{outer}}\n{{#for inner in INNER_LIST}}\n  Inner: {{inner}}\n{{/for}}\n"
    outer_condition = "outer in OUTER_LIST"
    
    # Process outer loop - it should process inner loop for each outer item
    result = process_for_construct(outer_condition, outer_content, 0)
    
    # Debug: print result to see what we got
    if (result == "") {
        print "FAIL: Result is empty"
        exit 1
    }
    
    # Count inner items by pattern matching (result may be in one line or multiple)
    # They should appear twice - once for each outer item = 2 outer * 2 inner = 4 total (2 of each)
    inner1_count = 0
    inner2_count = 0
    
    # Count occurrences of "Inner: inner1" and "Inner: inner2" in result
    temp_result = result
    while (match(temp_result, /Inner: inner1/)) {
        inner1_count++
        temp_result = substr(temp_result, RSTART + RLENGTH)
    }
    temp_result = result
    while (match(temp_result, /Inner: inner2/)) {
        inner2_count++
        temp_result = substr(temp_result, RSTART + RLENGTH)
    }
    
    # Verify nested for loop works: inner loop should execute for each outer item
    # Expected: 2 outer items * 2 inner items = 4 inner items total (2 of each)
    if (inner1_count != 2) {
        print "FAIL: Expected 2 occurrences of 'Inner: inner1' (one for each outer item), got " inner1_count ". Result: " substr(result, 1, 300)
        exit 1
    }
    if (inner2_count != 2) {
        print "FAIL: Expected 2 occurrences of 'Inner: inner2' (one for each outer item), got " inner2_count ". Result: " substr(result, 1, 300)
        exit 1
    }
    
    # Verify result is not empty and contains inner items
    if (result == "" || (inner1_count == 0 && inner2_count == 0)) {
        print "FAIL: Expected nested for loop to produce output with inner items. Got: " substr(result, 1, 200)
        exit 1
    }
    
    print "PASS"
}

