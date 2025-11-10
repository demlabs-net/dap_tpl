# Unit tests for dap_tpl_engine.awk - full pipeline tests
# Tests complete tokenize → evaluate → render pipeline

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/tokenizer.awk"
@include "core/evaluator.awk"
@include "core/renderer.awk"
@include "core/variable_functions.awk"

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

function test_simple_variable() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "value")
    ENVIRON["VAR"] = "value"
    
    template = "{{VAR}}"
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("simple variable pipeline", result == "value")
}

function test_if_true() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "1")
    ENVIRON["VAR"] = "1"
    
    template = "{{#if VAR}}Hello{{/if}}"
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("if true pipeline", result == "Hello")
}

function test_if_false() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "")
    ENVIRON["VAR"] = ""
    
    template = "{{#if VAR}}Hello{{/if}}"
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("if false pipeline", result == "")
}

function test_for_loop() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("ARRAY", "a|b|c")
    ENVIRON["ARRAY"] = "a|b|c"
    
    template = "{{#for item in ARRAY}}{{item}}{{/for}}"
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("for loop pipeline", result == "abc" || result ~ /a.*b.*c/)
}

function test_set_and_use() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    template = "{{#set VAR=test}}{{VAR}}{{/set}}"
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("set and use pipeline", result == "test")
}

function test_nested_for_in_if() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "1")
    set_var("ARRAY", "a|b")
    ENVIRON["VAR"] = "1"
    ENVIRON["ARRAY"] = "a|b"
    
    template = "{{#if VAR}}{{#for item in ARRAY}}{{item}}{{/for}}{{/if}}"
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("nested for in if pipeline", result ~ /a.*b/ || result == "ab")
}

function test_set_with_nested_variable() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("item", "test_value")
    ENVIRON["item"] = "test_value"
    
    template = "{{#set VAR={{item}}}}{{VAR}}{{/set}}"
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("set with nested variable pipeline", result == "test_value")
}

function test_set_with_function() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("entry", "a|b|c")
    ENVIRON["entry"] = "a|b|c"
    
    # First split
    split_result = process_variable_function("entry", "split", "pipe", "a|b|c")
    
    template = "{{entry|split|pipe}}{{#set VAR={{entry|part|0}}}}{{VAR}}{{/set}}"
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("set with function pipeline", result ~ /a/)
}

BEGIN {
    printf "Running dap_tpl_engine pipeline tests...\n\n"
    
    test_simple_variable()
    test_if_true()
    test_if_false()
    test_for_loop()
    test_set_and_use()
    test_nested_for_in_if()
    test_set_with_nested_variable()
    test_set_with_function()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

