# Unit tests for if_evaluator.awk

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"
@include "core/condition_parser.awk"
@include "core/construct_registry.awk"
@include "constructs/if/evaluator.awk"

# Include dispatch function stubs for tests
@include "tests/fixtures/dispatch_stubs.awk"

@include "core/evaluator_core.awk"

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

function test_if_true() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "1")
    ENVIRON["VAR"] = "1"
    
    metadata["condition"] = "VAR"
    if_id = create_token("if", "", metadata)
    text_id = create_token("text", "Hello", "")
    add_child(if_id, text_id)
    
    result_id = evaluate_if(if_id)
    
    test("if true returns root token", get_token_type(result_id) == "root")
    test("if true has 1 child", get_children_count(result_id) == 1)
    
    child = get_child(result_id, 1)
    test("if true child is text", get_token_type(child) == "text")
    test("if true child value", get_token_value(child) == "Hello")
}

function test_if_false() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "")
    ENVIRON["VAR"] = ""
    
    metadata["condition"] = "VAR"
    if_id = create_token("if", "", metadata)
    text_id = create_token("text", "Hello", "")
    add_child(if_id, text_id)
    
    result_id = evaluate_if(if_id)
    
    test("if false returns root token", get_token_type(result_id) == "root")
    test("if false has 0 children", get_children_count(result_id) == 0)
}

function test_if_with_else_true() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "1")
    ENVIRON["VAR"] = "1"
    
    metadata["condition"] = "VAR"
    if_id = create_token("if", "", metadata)
    text_id = create_token("text", "True", "")
    else_id = create_token("else", "", "")
    else_text_id = create_token("text", "False", "")
    add_child(if_id, text_id)
    add_child(if_id, else_id)
    add_child(else_id, else_text_id)
    
    result_id = evaluate_if(if_id)
    
    test("if-else true has 1 child", get_children_count(result_id) == 1)
    child = get_child(result_id, 1)
    test("if-else true child value", get_token_value(child) == "True")
}

function test_if_with_else_false() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "")
    ENVIRON["VAR"] = ""
    
    metadata["condition"] = "VAR"
    if_id = create_token("if", "", metadata)
    text_id = create_token("text", "True", "")
    else_id = create_token("else", "", "")
    else_text_id = create_token("text", "False", "")
    add_child(if_id, text_id)
    add_child(if_id, else_id)
    add_child(else_id, else_text_id)
    
    result_id = evaluate_if(if_id)
    
    test("if-else false has 1 child", get_children_count(result_id) == 1)
    child = get_child(result_id, 1)
    test("if-else false child value", get_token_value(child) == "False")
}

function test_if_with_function() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "test|value")
    ENVIRON["VAR"] = "test|value"
    
    # Split function returns empty string, so condition is false
    metadata["condition"] = "VAR|split|pipe"
    if_id = create_token("if", "", metadata)
    text_id = create_token("text", "Hello", "")
    add_child(if_id, text_id)
    
    result_id = evaluate_if(if_id)
    
    test("if with function returns root", get_token_type(result_id) == "root")
    # Split returns empty, so condition is false, no children
    test("if with function has 0 children", get_children_count(result_id) == 0)
}

BEGIN {
    printf "Running if_evaluator tests...\n\n"
    
    test_if_true()
    test_if_false()
    test_if_with_else_true()
    test_if_with_else_false()
    test_if_with_function()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

