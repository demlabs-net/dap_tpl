# Unit tests for logical AND parser

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

function test_parse_and_basic() {
    result = parse_condition("VAR1 && VAR2")
    test("AND: basic parse starts with AND", result ~ /^AND@@/)
}

function test_parse_and_with_spaces() {
    result = parse_condition("VAR1   &&   VAR2")
    test("AND: parse with multiple spaces", result ~ /^AND@@/)
}

function test_parse_and_nested() {
    result = parse_condition("VAR1 && VAR2 && VAR3")
    test("AND: nested AND expressions", result != "")
}

BEGIN {
    printf "Running logical AND parser tests...\n\n"
    
    test_parse_and_basic()
    test_parse_and_with_spaces()
    test_parse_and_nested()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}
