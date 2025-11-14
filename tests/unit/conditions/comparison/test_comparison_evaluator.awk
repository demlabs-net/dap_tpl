# Unit tests for comparison operators evaluator
# Tests evaluation of comparison conditions, especially string comparisons

@include "core/marker_parser.awk"
@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/condition_parser.awk"
@include "conditions/comparison/evaluator.awk"

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

function test_comparison_string_equals() {
    clear_contexts()
    push_context()
    
    set_var("type", "void")
    ENVIRON["type"] = "void"
    
    parsed = parse_condition("type == 'void'")
    result = evaluate_parsed_condition(parsed)
    test("Comparison: type == 'void' when type='void' (true)", result == 1)
    
    set_var("type", "int")
    ENVIRON["type"] = "int"
    
    parsed = parse_condition("type == 'void'")
    result = evaluate_parsed_condition(parsed)
    test("Comparison: type == 'void' when type='int' (false)", result == 0)
    
    set_var("type", "char")
    ENVIRON["type"] = "char"
    
    parsed = parse_condition("type == 'void'")
    result = evaluate_parsed_condition(parsed)
    test("Comparison: type == 'void' when type='char' (false)", result == 0)
}

function test_comparison_string_not_equals() {
    clear_contexts()
    push_context()
    
    set_var("type", "void")
    ENVIRON["type"] = "void"
    
    parsed = parse_condition("type != 'void'")
    result = evaluate_parsed_condition(parsed)
    test("Comparison: type != 'void' when type='void' (false)", result == 0)
    
    set_var("type", "int")
    ENVIRON["type"] = "int"
    
    parsed = parse_condition("type != 'void'")
    result = evaluate_parsed_condition(parsed)
    test("Comparison: type != 'void' when type='int' (true)", result == 1)
}

function test_comparison_in_for_loop_context() {
    clear_contexts()
    push_context()
    
    # Simulate for loop: type="void"
    set_var("type", "void")
    ENVIRON["type"] = "void"
    
    parsed = parse_condition("type == 'void'")
    result = evaluate_parsed_condition(parsed)
    test("For loop context: type == 'void' when type='void' (true)", result == 1)
    
    # Simulate for loop: type="int"
    set_var("type", "int")
    ENVIRON["type"] = "int"
    
    parsed = parse_condition("type == 'void'")
    result = evaluate_parsed_condition(parsed)
    test("For loop context: type == 'void' when type='int' (false)", result == 0)
    
    # Simulate for loop: type="char"
    set_var("type", "char")
    ENVIRON["type"] = "char"
    
    parsed = parse_condition("type == 'void'")
    result = evaluate_parsed_condition(parsed)
    test("For loop context: type == 'void' when type='char' (false)", result == 0)
}

function test_comparison_multiple_types() {
    clear_contexts()
    push_context()
    
    # Test with multiple types in sequence (simulating for loop iterations)
    types["void"] = "void"
    types["int"] = "int"
    types["char"] = "char"
    
    for (t in types) {
        set_var("type", types[t])
        ENVIRON["type"] = types[t]
        
        parsed = parse_condition("type == 'void'")
        result = evaluate_parsed_condition(parsed)
        
        expected = (types[t] == "void") ? 1 : 0
        test_name = sprintf("Multiple types: type == 'void' when type='%s' (%s)", types[t], (expected == 1) ? "true" : "false")
        test(test_name, result == expected)
    }
}

BEGIN {
    printf "Running comparison evaluator tests...\n\n"
    
    test_comparison_string_equals()
    test_comparison_string_not_equals()
    test_comparison_in_for_loop_context()
    test_comparison_multiple_types()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

