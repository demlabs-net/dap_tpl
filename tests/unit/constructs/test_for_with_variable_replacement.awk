# Test for construct with variable replacement in content
# Tests {{#for item in LIST}} ... {{item}} ... {{/for}}

@include "constructs/modules/for_construct.awk"
@include "core/variable_replacer.awk"
@include "constructs/modules/nested_constructs.awk"
@include "constructs/modules/awk_sections.awk"

BEGIN {
    ENVIRON["MOCK_LIST"] = "mock1|mock2|mock3"
    
    # For loop with variable replacement
    condition = "mock_entry in MOCK_LIST"
    content = "#include \"{{mock_entry}}_mock.h\"\n"
    recursion_depth = 0
    
    # Process construct using function
    result = process_for_construct(condition, content, recursion_depth)
    
    # Verify result contains all three includes
    if (result !~ /#include "mock1_mock.h"/) {
        print "FAIL: Expected '#include \"mock1_mock.h\"' in result"
        exit 1
    }
    if (result !~ /#include "mock2_mock.h"/) {
        print "FAIL: Expected '#include \"mock2_mock.h\"' in result"
        exit 1
    }
    if (result !~ /#include "mock3_mock.h"/) {
        print "FAIL: Expected '#include \"mock3_mock.h\"' in result"
        exit 1
    }
    
    print "PASS"
}

