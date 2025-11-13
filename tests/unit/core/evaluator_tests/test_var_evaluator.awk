# Unit tests for var_evaluator.awk

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "constructs/var/evaluator.awk"

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

function test_var_simple() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "value")
    ENVIRON["VAR"] = "value"
    
    var_id = create_token("var", "", "")
    set_token_metadata(var_id, "var_name", "VAR")
    
    result_id = evaluate_var(var_id)
    
    test("var simple returns text token", get_token_type(result_id) == "text")
    test("var simple value", get_token_value(result_id) == "value")
}

function test_var_with_split() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "a|b|c")
    ENVIRON["VAR"] = "a|b|c"
    
    var_id = create_token("var", "", "")
    set_token_metadata(var_id, "var_name", "VAR|split|pipe")
    
    result_id = evaluate_var(var_id)
    
    test("var split returns text", get_token_type(result_id) == "text")
    test("var split parts count set", get_var("VAR_parts_count") == "3")
    test("var split part 0", get_var("VAR_parts_0") == "a")
    test("var split part 1", get_var("VAR_parts_1") == "b")
    test("var split part 2", get_var("VAR_parts_2") == "c")
}

function test_var_with_part() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("VAR", "a|b|c")
    ENVIRON["VAR"] = "a|b|c"
    
    # First split
    split_result = process_variable_function("VAR", "split", "pipe", "a|b|c")
    set_var("VAR_parts_count", "3")
    set_var("VAR_parts_0", "a")
    set_var("VAR_parts_1", "b")
    set_var("VAR_parts_2", "c")
    ENVIRON["VAR_parts_count"] = "3"
    ENVIRON["VAR_parts_0"] = "a"
    ENVIRON["VAR_parts_1"] = "b"
    ENVIRON["VAR_parts_2"] = "c"
    
    var_id = create_token("var", "", "")
    set_token_metadata(var_id, "var_name", "VAR|part|1")
    
    result_id = evaluate_var(var_id)
    
    test("var part returns text", get_token_type(result_id) == "text")
    test("var part value", get_token_value(result_id) == "b")
}

function test_var_not_found() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    var_id = create_token("var", "", "")
    set_token_metadata(var_id, "var_name", "NONEXISTENT")
    
    result_id = evaluate_var(var_id)
    
    test("var not found returns text", get_token_type(result_id) == "text")
    test("var not found value empty", get_token_value(result_id) == "")
}

function test_var_environ_fallback() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    ENVIRON["ENV_VAR"] = "env_value"
    
    var_id = create_token("var", "", "")
    set_token_metadata(var_id, "var_name", "ENV_VAR")
    
    result_id = evaluate_var(var_id)
    
    test("var environ fallback returns text", get_token_type(result_id) == "text")
    test("var environ fallback value", get_token_value(result_id) == "env_value")
}

BEGIN {
    printf "Running var_evaluator tests...\n\n"
    
    test_var_simple()
    test_var_with_split()
    test_var_with_part()
    test_var_not_found()
    test_var_environ_fallback()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

