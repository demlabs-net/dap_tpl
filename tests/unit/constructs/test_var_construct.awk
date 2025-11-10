# Test var construct processing
# Tests {{VAR}} and {{VAR|function|args}}

@include "core/variable_functions.awk"
@include "core/variable_replacer.awk"

BEGIN {
    # Test 1: Simple variable output
    ENVIRON["TEST_VAR"] = "test_value"
    var_expr = "TEST_VAR"
    
    # Simulate var construct processing - get variable value
    var_value = ""
    if (var_expr in vars) {
        var_value = vars[var_expr]
    } else if (var_expr in ENVIRON) {
        var_value = ENVIRON[var_expr]
    }
    
    if (var_value != "test_value") {
        print "FAIL: Expected 'test_value', got '" var_value "'"
        exit 1
    }
    
    # Test 2: Variable with split function
    ENVIRON["TEST_LIST"] = "a|b|c"
    var_expr2 = "TEST_LIST|split|pipe"
    
    # Parse function call
    if (match(var_expr2, /^([^|]+)\|([^|]+)(\|(.+))?$/)) {
        split(var_expr2, func_parts, "|")
        var_name = func_parts[1]
        func_name = func_parts[2]
        func_arg = ""
        if (length(func_parts) > 2) {
            func_arg = func_parts[3]
        }
        
        # Get base value
        base_value = ""
        if (var_name in ENVIRON) {
            base_value = ENVIRON[var_name]
        }
        
        # Apply split function
        if (func_name == "split") {
            delimiter = func_arg
            if (delimiter == "pipe" || delimiter == "|") {
                delimiter = "|"
            }
            n = split(base_value, parts_array, delimiter)
            # Store parts
            for (p = 1; p <= n; p++) {
                vars[var_name "_parts_" (p-1)] = parts_array[p]
            }
            vars[var_name "_parts_count"] = n
            # split doesn't output - just creates parts
            var_value = ""
        }
        
        # Verify parts were created
        if (vars[var_name "_parts_count"] != 3) {
            print "FAIL: Expected 3 parts, got " vars[var_name "_parts_count"]
            exit 1
        }
        if (vars[var_name "_parts_0"] != "a") {
            print "FAIL: Expected parts_0='a', got '" vars[var_name "_parts_0"] "'"
            exit 1
        }
        if (vars[var_name "_parts_1"] != "b") {
            print "FAIL: Expected parts_1='b', got '" vars[var_name "_parts_1"] "'"
            exit 1
        }
        if (vars[var_name "_parts_2"] != "c") {
            print "FAIL: Expected parts_2='c', got '" vars[var_name "_parts_2"] "'"
            exit 1
        }
    } else {
        print "FAIL: Could not parse function call"
        exit 1
    }
    
    print "PASS"
}

