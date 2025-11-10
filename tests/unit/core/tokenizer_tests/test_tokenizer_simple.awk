# Unit tests for tokenizer.awk - simple cases

@include "core/tokenizer.awk"

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

function test_simple_text() {
    clear_token_tree()
    
    template = "Hello World"
    root_id = tokenize(template)
    
    test("root token created", root_id > 0)
    test("root has 1 child", get_children_count(root_id) == 1)
    
    child_id = get_child(root_id, 1)
    test("child is text token", get_token_type(child_id) == "text")
    test("child value is correct", get_token_value(child_id) == "Hello World")
}

function test_simple_variable() {
    clear_token_tree()
    
    template = "Hello {{name}}"
    root_id = tokenize(template)
    
    test("root has 2 children", get_children_count(root_id) == 2)
    
    child1 = get_child(root_id, 1)
    child2 = get_child(root_id, 2)
    
    test("first child is text", get_token_type(child1) == "text")
    test("second child is var", get_token_type(child2) == "var")
    test("var name is correct", get_token_metadata(child2, "var_name") == "name")
}

function test_simple_if() {
    clear_token_tree()
    
    template = "{{#if VAR}}Hello{{/if}}"
    root_id = tokenize(template)
    
    test("root has 1 child", get_children_count(root_id) == 1)
    
    if_id = get_child(root_id, 1)
    test("child is if token", get_token_type(if_id) == "if")
    test("if condition is correct", get_token_metadata(if_id, "condition") == "VAR")
    test("if has 1 child", get_children_count(if_id) == 1)
    
    text_id = get_child(if_id, 1)
    test("if child is text", get_token_type(text_id) == "text")
    test("if child value is correct", get_token_value(text_id) == "Hello")
}

BEGIN {
    printf "Running simple tokenizer tests...\n\n"
    
    test_simple_text()
    test_simple_variable()
    test_simple_if()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

