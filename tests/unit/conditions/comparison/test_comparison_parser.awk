# Unit tests for comparison operators parser

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

function test_parse_equals() {
    result = parse_condition("VAR == 5")
    test("Comparison: parse == operator", result ~ /^==\|/)
}

function test_parse_not_equals() {
    result = parse_condition("VAR != 0")
    test("Comparison: parse != operator", result ~ /^!=\|/)
}

function test_parse_greater_than() {
    result = parse_condition("VAR > 10")
    test("Comparison: parse > operator", result ~ /^>\|/)
}

function test_parse_less_than() {
    result = parse_condition("VAR < 100")
    test("Comparison: parse < operator", result ~ /^<\|/)
}

function test_parse_gte() {
    result = parse_condition("VAR >= 5")
    test("Comparison: parse >= operator", result ~ /^>=\|/)
}

function test_parse_lte() {
    result = parse_condition("VAR <= 20")
    test("Comparison: parse <= operator", result ~ /^<=\|/)
}

function test_parse_with_quotes() {
    result = parse_condition("VAR == 'text'")
    test("Comparison: parse with quoted string", result ~ /^==\|/)
}

BEGIN {
    printf "Running comparison parser tests...\n\n"
    
    test_parse_equals()
    test_parse_not_equals()
    test_parse_greater_than()
    test_parse_less_than()
    test_parse_gte()
    test_parse_lte()
    test_parse_with_quotes()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}
