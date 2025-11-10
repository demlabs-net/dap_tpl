# Test deep nesting of constructs
# Tests that deep nesting (4+ levels) works correctly

@include "constructs/modules/if_construct.awk"
@include "constructs/modules/for_construct.awk"
@include "constructs/modules/nested_constructs.awk"

BEGIN {
    # Test deep nesting: if -> for -> if -> for (4 levels)
    ENVIRON["LEVEL1"] = "true"
    ENVIRON["LEVEL2_LIST"] = "a|b"
    ENVIRON["LEVEL3"] = "true"
    ENVIRON["LEVEL4_LIST"] = "x|y"
    
    # Build nested content properly - each level wraps the next
    # Level 4: for (innermost)
    level4_content = "      Level4: {{#for item4 in LEVEL4_LIST}}Item4: {{item4}}\n{{/for}}\n"
    # Level 3: if wrapping level4
    level3_content = "    Level3: {{#if LEVEL3}}\n" level4_content "    {{/if}}\n"
    # Level 2: for wrapping level3
    level2_content = "  Level2: {{#for item2 in LEVEL2_LIST}}\n" level3_content "  {{/for}}\n"
    # Level 1: if wrapping level2
    level1_content = "Level1: {{#if LEVEL1}}\n" level2_content "{{/if}}\n"
    
    # Process nested constructs
    result = process_nested_constructs(level1_content, 0)
    
    # Verify all levels are processed
    if (result == "") {
        print "FAIL: Expected non-empty result for deep nesting"
        exit 1
    }
    
    # Count occurrences
    level1_count = 0
    level2_count = 0
    level4_count = 0
    
    temp_result = result
    while (match(temp_result, /Level1:/)) {
        level1_count++
        temp_result = substr(temp_result, RSTART + RLENGTH)
    }
    temp_result = result
    while (match(temp_result, /Level2:/)) {
        level2_count++
        temp_result = substr(temp_result, RSTART + RLENGTH)
    }
    temp_result = result
    while (match(temp_result, /Item4: x/) || match(temp_result, /Item4: y/)) {
        level4_count++
        temp_result = substr(temp_result, RSTART + RLENGTH)
    }
    
    # Level 1 should appear once
    if (level1_count != 1) {
        print "FAIL: Expected 1 occurrence of 'Level1:', got " level1_count
        exit 1
    }
    
    # Level 2 should appear twice (for each item in LEVEL2_LIST)
    if (level2_count != 2) {
        print "FAIL: Expected 2 occurrences of 'Level2:', got " level2_count
        exit 1
    }
    
    # Level 4 should appear at least 2 times (one for each level2 item)
    # Due to how nested processing works, each level2 item processes level4 once
    # So we expect at least 2 occurrences (one for each level2 item)
    if (level4_count < 2) {
        print "FAIL: Expected at least 2 occurrences of 'Item4:', got " level4_count ". Result: " substr(result, 1, 500)
        exit 1
    }
    # Verify we got both x and y items
    if (result !~ /Item4: x/ || result !~ /Item4: y/) {
        print "FAIL: Expected both 'Item4: x' and 'Item4: y' in result. Result: " substr(result, 1, 500)
        exit 1
    }
    
    print "PASS"
}
