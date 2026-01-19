# Unit tests for not_contains operator evaluator

@include "core/marker_parser.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/condition_parser.awk"
@include "core/condition_evaluator.awk"

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

function test_evaluate_not_contains_true() {
    VARS["TEST"] = "foo bar baz"
    result = evaluate_condition("TEST not_contains 'xyz'")
    test("Not_contains: returns true when substring not found", result == 1)
}

function test_evaluate_not_contains_false() {
    VARS["TEST"] = "foo bar baz"
    result = evaluate_condition("TEST not_contains 'bar'")
    test("Not_contains: returns false when substring found", result == 0)
}

function test_evaluate_not_contains_empty_var() {
    VARS["TEST"] = ""
    result = evaluate_condition("TEST not_contains 'foo'")
    test("Not_contains: empty variable doesn't contain anything", result == 1)
}

function test_evaluate_not_contains_partial_match() {
    VARS["TEST"] = "dap_ledger_tx_add"
    result = evaluate_condition("TEST not_contains 'dap_ledger_tx_find'")
    test("Not_contains: partial function name doesn't match", result == 1)
}

function test_evaluate_not_contains_exact_match() {
    VARS["TEST"] = "func1\nfunc2\nfunc3"
    result = evaluate_condition("TEST not_contains 'func2'")
    test("Not_contains: finds exact match in multiline", result == 0)
}

BEGIN {
    printf "Running not_contains evaluator tests...\n\n"
    
    test_evaluate_not_contains_true()
    test_evaluate_not_contains_false()
    test_evaluate_not_contains_empty_var()
    test_evaluate_not_contains_partial_match()
    test_evaluate_not_contains_exact_match()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}
