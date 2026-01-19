# Unit tests for not_contains operator parser

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

function test_parse_not_contains_basic() {
    result = parse_condition("VAR not_contains 'text'")
    test("Not_contains: basic parse", result ~ /^not_contains\|/)
}

function test_parse_not_contains_no_quotes() {
    result = parse_condition("VAR not_contains text")
    test("Not_contains: without quotes", result ~ /^not_contains\|/)
}

function test_parse_not_contains_with_spaces() {
    result = parse_condition("VAR   not_contains   'hello world'")
    test("Not_contains: with extra spaces", result ~ /^not_contains\|/)
}

function test_parse_not_contains_variable_function() {
    result = parse_condition("VAR|part|0 not_contains 'foo'")
    test("Not_contains: with variable function", result ~ /^not_contains\|/)
}

BEGIN {
    printf "Running not_contains parser tests...\n\n"
    
    test_parse_not_contains_basic()
    test_parse_not_contains_no_quotes()
    test_parse_not_contains_with_spaces()
    test_parse_not_contains_variable_function()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}
