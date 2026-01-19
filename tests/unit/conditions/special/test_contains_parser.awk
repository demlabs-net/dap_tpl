# Unit tests for contains operator parser

@include "core/marker_parser.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
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

function test_parse_contains_basic() {
    result = parse_condition("VAR contains 'text'")
    test("Contains: basic parse", result ~ /^contains\|/)
}

function test_parse_contains_no_quotes() {
    result = parse_condition("VAR contains text")
    test("Contains: without quotes", result ~ /^contains\|/)
}

function test_parse_contains_with_spaces() {
    result = parse_condition("VAR   contains   'hello world'")
    test("Contains: with extra spaces", result ~ /^contains\|/)
}

BEGIN {
    printf "Running contains parser tests...\n\n"
    
    test_parse_contains_basic()
    test_parse_contains_no_quotes()
    test_parse_contains_with_spaces()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}
