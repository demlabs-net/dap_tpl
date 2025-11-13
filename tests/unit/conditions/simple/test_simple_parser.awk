# Unit tests for simple variable parser

@include "core/marker_parser.awk"
@include "core/condition_parser.awk"

BEGIN {
    test_count = 0
    pass_count = 0
    fail_count = 0
}

function test(name, condition) {
    test_count++
    if (condition) {
        pass_count++
        printf "PASS: %s\n", name
    } else {
        fail_count++
        printf "FAIL: %s\n", name
    }
}

function test_parse_simple_var_basic() {
    result = parse_condition("VAR")
    test("Simple: basic variable", result != "")
}

function test_parse_simple_var_with_function() {
    result = parse_condition("VAR|len")
    test("Simple: variable with function", result != "")
}

function test_parse_simple_var_empty() {
    result = parse_condition("")
    test("Simple: empty expression returns empty", result == "")
}

BEGIN {
    printf "Running simple variable parser tests...\n\n"
    
    test_parse_simple_var_basic()
    test_parse_simple_var_with_function()
    test_parse_simple_var_empty()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}
