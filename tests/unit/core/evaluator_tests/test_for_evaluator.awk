# Unit tests for for_evaluator.awk

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/evaluators/for_evaluator.awk"

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

function test_for_pipe_separated() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("ARRAY", "a|b|c")
    ENVIRON["ARRAY"] = "a|b|c"
    
    metadata["condition"] = "item in ARRAY"
    for_id = create_token("for", "", metadata)
    var_id = create_token("var", "", "")
    var_metadata["var_name"] = "item"
    set_token_metadata(var_id, "var_name", "item")
    add_child(for_id, var_id)
    
    result_id = evaluate_for(for_id)
    
    test("for pipe returns root", get_token_type(result_id) == "root")
    test("for pipe has 3 children", get_children_count(result_id) == 3)
}

function test_for_newline_separated() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("ARRAY", "a\nb\nc")
    ENVIRON["ARRAY"] = "a\nb\nc"
    
    metadata["condition"] = "item in ARRAY"
    for_id = create_token("for", "", metadata)
    var_id = create_token("var", "", "")
    set_token_metadata(var_id, "var_name", "item")
    add_child(for_id, var_id)
    
    result_id = evaluate_for(for_id)
    
    test("for newline returns root", get_token_type(result_id) == "root")
    test("for newline has 3 children", get_children_count(result_id) == 3)
}

function test_for_empty_array() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("ARRAY", "")
    ENVIRON["ARRAY"] = ""
    
    metadata["condition"] = "item in ARRAY"
    for_id = create_token("for", "", metadata)
    var_id = create_token("var", "", "")
    set_token_metadata(var_id, "var_name", "item")
    add_child(for_id, var_id)
    
    result_id = evaluate_for(for_id)
    
    test("for empty returns root", get_token_type(result_id) == "root")
    test("for empty has 0 children", get_children_count(result_id) == 0)
}

function test_for_variable_scoping() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("ARRAY", "a|b")
    ENVIRON["ARRAY"] = "a|b"
    set_var("item", "outer")
    ENVIRON["item"] = "outer"
    
    metadata["condition"] = "item in ARRAY"
    for_id = create_token("for", "", metadata)
    var_id = create_token("var", "", "")
    set_token_metadata(var_id, "var_name", "item")
    add_child(for_id, var_id)
    
    result_id = evaluate_for(for_id)
    
    test("for scoping returns root", get_token_type(result_id) == "root")
    test("for scoping has 2 children", get_children_count(result_id) == 2)
    
    # After loop, outer value should be restored
    test("outer value restored", get_var("item") == "outer")
}

BEGIN {
    printf "Running for_evaluator tests...\n\n"
    
    test_for_pipe_separated()
    test_for_newline_separated()
    test_for_empty_array()
    test_for_variable_scoping()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

