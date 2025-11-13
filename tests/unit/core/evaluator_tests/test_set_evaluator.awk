# Unit tests for set_evaluator.awk

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "constructs/set/evaluator.awk"

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

function test_set_simple_value() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    metadata["condition"] = "VAR=value"
    set_id = create_token("set", "", metadata)
    
    result_id = evaluate_set(set_id)
    
    test("set simple returns root", get_token_type(result_id) == "root")
    test("set simple variable set", get_var("VAR") == "value")
    test("set simple ENVIRON set", ENVIRON["VAR"] == "value")
}

function test_set_with_nested_variable() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("item", "test_value")
    ENVIRON["item"] = "test_value"
    
    metadata["condition"] = "VAR={{item}}"
    set_id = create_token("set", "", metadata)
    
    result_id = evaluate_set(set_id)
    
    test("set nested returns root", get_token_type(result_id) == "root")
    test("set nested variable set", get_var("VAR") == "test_value")
    test("set nested ENVIRON set", ENVIRON["VAR"] == "test_value")
}

function test_set_with_function() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("entry", "a|b|c")
    ENVIRON["entry"] = "a|b|c"
    
    # First split
    split_result = process_variable_function("entry", "split", "pipe", "a|b|c")
    
    metadata["condition"] = "VAR={{entry|part|0}}"
    set_id = create_token("set", "", metadata)
    
    result_id = evaluate_set(set_id)
    
    test("set function returns root", get_token_type(result_id) == "root")
    test("set function variable set", get_var("VAR") == "a")
}

function test_set_value_evaluation() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("a", "A")
    set_var("b", "B")
    ENVIRON["a"] = "A"
    ENVIRON["b"] = "B"
    
    result = evaluate_set_value("{{a}}{{b}}")
    
    test("set value evaluation", result == "AB")
}

function test_set_value_nested_markers() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("outer", "{{inner}}")
    set_var("inner", "value")
    ENVIRON["outer"] = "{{inner}}"
    ENVIRON["inner"] = "value"
    
    result = evaluate_set_value("{{outer}}")
    
    test("set value nested markers", result == "value")
}

BEGIN {
    printf "Running set_evaluator tests...\n\n"
    
    test_set_simple_value()
    test_set_with_nested_variable()
    test_set_with_function()
    test_set_value_evaluation()
    test_set_value_nested_markers()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

