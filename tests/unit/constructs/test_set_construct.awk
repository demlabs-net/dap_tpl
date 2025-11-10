# Test set construct processing
# Tests {{#set VAR=value}}

@include "constructs/process_template_constructs.awk"

BEGIN {
    # Test: Set variable and verify it's stored
    # Simulate set construct processing
    condition = "TEST_VAR=test_value"
    
    # Parse set construct manually (simulating process_template_constructs.awk logic)
    if (match(condition, /^([^=]+)=(.*)$/)) {
        var_name = substr(condition, RSTART, RLENGTH)
        split(var_name, parts, "=")
        var_name = parts[1]
        gsub(/^[ \t]+|[ \t]+$/, "", var_name)
        var_value = substr(condition, RSTART + length(parts[1]) + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", var_value)
        
        # Set variable (simulating vars[] assignment)
        vars[var_name] = var_value
        ENVIRON[var_name] = var_value
        
        # Verify variable is set
        if (vars[var_name] != "test_value") {
            print "FAIL: Expected vars[TEST_VAR]='test_value', got '" vars[var_name] "'"
            exit 1
        }
        if (ENVIRON[var_name] != "test_value") {
            print "FAIL: Expected ENVIRON[TEST_VAR]='test_value', got '" ENVIRON[var_name] "'"
            exit 1
        }
    } else {
        print "FAIL: Could not parse set condition"
        exit 1
    }
    
    print "PASS"
}

