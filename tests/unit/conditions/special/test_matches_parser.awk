# Unit tests for matches operator parser

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

function test_parse_matches_basic() {
    result = parse_condition("VAR matches '^test'")
    test("Matches: basic regex pattern", result ~ /^matches\|/)
}

function test_parse_matches_complex() {
    result = parse_condition("VAR matches '[0-9]+'")
    test("Matches: complex regex pattern", result ~ /^matches\|/)
}

function test_parse_matches_with_spaces() {
    result = parse_condition("VAR   matches   'pattern.*'")
    test("Matches: with extra spaces", result ~ /^matches\|/)
}

BEGIN {
    printf "Running matches parser tests...\n\n"
    
    test_parse_matches_basic()
    test_parse_matches_complex()
    test_parse_matches_with_spaces()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}
