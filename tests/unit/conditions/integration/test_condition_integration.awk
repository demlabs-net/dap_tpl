# Integration tests for condition system
# Tests full condition parsing and evaluation pipeline

@include "core/variable_context.awk"
@include "core/variable_functions.awk"
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

function test_logical_and() {
    clear_contexts()
    push_context()
    set_var("A", "1")
    set_var("B", "1")
    
    parsed = parse_condition("A && B")
    result = evaluate_parsed_condition(parsed)
    test("Integration: A && B (both true)", result == 1)
    
    set_var("B", "0")
    parsed = parse_condition("A && B")
    result = evaluate_parsed_condition(parsed)
    test("Integration: A && B (one false)", result == 0)
}

function test_logical_or() {
    clear_contexts()
    push_context()
    set_var("A", "1")
    set_var("B", "0")
    
    parsed = parse_condition("A || B")
    result = evaluate_parsed_condition(parsed)
    test("Integration: A || B (one true)", result == 1)
    
    set_var("A", "0")
    parsed = parse_condition("A || B")
    result = evaluate_parsed_condition(parsed)
    test("Integration: A || B (both false)", result == 0)
}

function test_logical_not() {
    clear_contexts()
    push_context()
    set_var("A", "0")
    
    parsed = parse_condition("! A")
    result = evaluate_parsed_condition(parsed)
    test("Integration: ! A (A is false)", result == 1)
    
    set_var("A", "1")
    parsed = parse_condition("! A")
    result = evaluate_parsed_condition(parsed)
    test("Integration: ! A (A is true)", result == 0)
}

function test_comparison_eq() {
    clear_contexts()
    push_context()
    set_var("VAR", "5")
    
    parsed = parse_condition("VAR == 5")
    result = evaluate_parsed_condition(parsed)
    test("Integration: VAR == 5 (true)", result == 1)
    
    parsed = parse_condition("VAR == 10")
    result = evaluate_parsed_condition(parsed)
    test("Integration: VAR == 10 (false)", result == 0)
}

function test_comparison_ne() {
    clear_contexts()
    push_context()
    set_var("VAR", "5")
    
    parsed = parse_condition("VAR != 10")
    result = evaluate_parsed_condition(parsed)
    test("Integration: VAR != 10 (true)", result == 1)
    
    parsed = parse_condition("VAR != 5")
    result = evaluate_parsed_condition(parsed)
    test("Integration: VAR != 5 (false)", result == 0)
}

function test_comparison_gt() {
    clear_contexts()
    push_context()
    set_var("VAR", "10")
    
    parsed = parse_condition("VAR > 5")
    result = evaluate_parsed_condition(parsed)
    test("Integration: VAR > 5 (true)", result == 1)
    
    parsed = parse_condition("VAR > 20")
    result = evaluate_parsed_condition(parsed)
    test("Integration: VAR > 20 (false)", result == 0)
}

function test_contains() {
    clear_contexts()
    push_context()
    set_var("TEXT", "hello world")
    
    parsed = parse_condition("TEXT contains 'world'")
    result = evaluate_parsed_condition(parsed)
    test("Integration: TEXT contains 'world' (true)", result == 1)
    
    parsed = parse_condition("TEXT contains 'foo'")
    result = evaluate_parsed_condition(parsed)
    test("Integration: TEXT contains 'foo' (false)", result == 0)
}

function test_matches() {
    clear_contexts()
    push_context()
    set_var("TEXT", "test123")
    
    parsed = parse_condition("TEXT matches '[0-9]+'")
    result = evaluate_parsed_condition(parsed)
    test("Integration: TEXT matches '[0-9]+' (true)", result == 1)
    
    parsed = parse_condition("TEXT matches '^[0-9]+$'")
    result = evaluate_parsed_condition(parsed)
    test("Integration: TEXT matches '^[0-9]+$' (false)", result == 0)
}

function test_complex_expression() {
    clear_contexts()
    push_context()
    set_var("A", "5")
    set_var("B", "10")
    set_var("C", "1")
    
    # (A > 3 && B < 20) || C
    parsed = parse_condition("A > 3 && B < 20")
    result = evaluate_parsed_condition(parsed)
    test("Integration: Complex (A > 3 && B < 20)", result == 1)
}

function test_simple_variable() {
    clear_contexts()
    push_context()
    set_var("VAR", "1")
    
    parsed = parse_condition("VAR")
    result = evaluate_parsed_condition(parsed)
    test("Integration: Simple VAR (true)", result == 1)
    
    set_var("VAR", "0")
    parsed = parse_condition("VAR")
    result = evaluate_parsed_condition(parsed)
    test("Integration: Simple VAR (false, 0)", result == 0)
    
    set_var("VAR", "")
    parsed = parse_condition("VAR")
    result = evaluate_parsed_condition(parsed)
    test("Integration: Simple VAR (false, empty)", result == 0)
}

BEGIN {
    printf "Running condition system integration tests...\n\n"
    
    test_logical_and()
    test_logical_or()
    test_logical_not()
    test_comparison_eq()
    test_comparison_ne()
    test_comparison_gt()
    test_contains()
    test_matches()
    test_complex_expression()
    test_simple_variable()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

