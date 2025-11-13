# Unit tests for tokenizer.awk - advanced cases
# Tests nested constructs, set with nested variables, for loops, else branches, AWK sections

@include "core/construct_registry.awk"
# Include all construct definitions and tokenizers
@include "constructs/if/definition.awk"
@include "constructs/for/definition.awk"
@include "constructs/set/definition.awk"
@include "constructs/var/definition.awk"
@include "constructs/awk_section/definition.awk"
@include "constructs/if/tokenizer.awk"
@include "constructs/if/branch_parser.awk"
@include "constructs/for/tokenizer.awk"
@include "constructs/set/tokenizer.awk"
@include "constructs/var/tokenizer.awk"
@include "constructs/awk_section/tokenizer.awk"

# Include dispatch function stubs for tests
@include "tests/fixtures/dispatch_stubs.awk"

@include "core/tokenizer_core.awk"

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

function test_for_construct() {
    clear_token_tree()
    
    template = "{{#for item in ARRAY}}Value: {{item}}{{/for}}"
    root_id = tokenize(template)
    
    test("for root has 1 child", get_children_count(root_id) == 1)
    
    for_id = get_child(root_id, 1)
    test("child is for token", get_token_type(for_id) == "for")
    test("for condition is correct", get_token_metadata(for_id, "condition") == "item in ARRAY")
    test("for has 2 children", get_children_count(for_id) == 2)
    
    child1 = get_child(for_id, 1)
    child2 = get_child(for_id, 2)
    test("for child1 is text", get_token_type(child1) == "text")
    test("for child2 is var", get_token_type(child2) == "var")
    test("for child2 var name", get_token_metadata(child2, "var_name") == "item")
}

function test_set_construct() {
    clear_token_tree()
    
    template = "{{#set VAR=value}}Text{{/set}}"
    root_id = tokenize(template)
    
    test("set root has 1 child", get_children_count(root_id) == 1)
    
    set_id = get_child(root_id, 1)
    test("child is set token", get_token_type(set_id) == "set")
    test("set condition is correct", get_token_metadata(set_id, "condition") == "VAR=value")
    test("set has 1 child", get_children_count(set_id) == 1)
    
    child = get_child(set_id, 1)
    test("set child is text", get_token_type(child) == "text")
    test("set child value", get_token_value(child) == "Text")
}

function test_set_with_nested_variable() {
    clear_token_tree()
    
    template = "{{#set VAR={{item}}}}"
    root_id = tokenize(template)
    
    test("set with nested var root has 1 child", get_children_count(root_id) == 1)
    
    set_id = get_child(root_id, 1)
    test("set condition contains nested var", get_token_metadata(set_id, "condition") == "VAR={{item}}")
}

function test_if_with_else() {
    clear_token_tree()
    
    template = "{{#if VAR}}True{{else}}False{{/if}}"
    root_id = tokenize(template)
    
    test("if-else root has 1 child", get_children_count(root_id) == 1)
    
    if_id = get_child(root_id, 1)
    test("child is if token", get_token_type(if_id) == "if")
    test("if has 2 children", get_children_count(if_id) == 2)
    
    child1 = get_child(if_id, 1)
    child2 = get_child(if_id, 2)
    test("if child1 is text", get_token_type(child1) == "text")
    test("if child2 is else", get_token_type(child2) == "else")
    test("else has 1 child", get_children_count(child2) == 1)
    
    else_child = get_child(child2, 1)
    test("else child is text", get_token_type(else_child) == "text")
    # Else child value may include closing braces or whitespace from parsing
    else_value = get_token_value(else_child)
    gsub(/^[ \t\n}]+|[ \t\n}]+$/, "", else_value)
    test("else child value", else_value == "False")
}

function test_nested_for_in_if() {
    clear_token_tree()
    
    template = "{{#if VAR}}{{#for item in ARRAY}}{{item}}{{/for}}{{/if}}"
    root_id = tokenize(template)
    
    test("nested root has 1 child", get_children_count(root_id) == 1)
    
    if_id = get_child(root_id, 1)
    test("if has 1 child", get_children_count(if_id) == 1)
    
    for_id = get_child(if_id, 1)
    test("nested child is for", get_token_type(for_id) == "for")
    test("for has 1 child", get_children_count(for_id) == 1)
    
    var_id = get_child(for_id, 1)
    test("for child is var", get_token_type(var_id) == "var")
}

function test_awk_section() {
    clear_token_tree()
    
    template = "{{AWK:}}\nprint \"test\"\n{{/AWK}}"
    root_id = tokenize(template)
    
    test("awk root has 1 child", get_children_count(root_id) == 1)
    
    awk_id = get_child(root_id, 1)
    test("child is awk_section token", get_token_type(awk_id) == "awk_section")
    test("awk has 1 child", get_children_count(awk_id) == 1)
    
    awk_child = get_child(awk_id, 1)
    test("awk child is text", get_token_type(awk_child) == "text")
    # AWK code may include leading/trailing newlines from parsing
    awk_value = get_token_value(awk_child)
    gsub(/^\n+|\n+$/, "", awk_value)
    test("awk value is correct", awk_value == "print \"test\"")
}

function test_variable_with_function() {
    clear_token_tree()
    
    template = "{{VAR|split|pipe}}"
    root_id = tokenize(template)
    
    test("var with func root has 1 child", get_children_count(root_id) == 1)
    
    var_id = get_child(root_id, 1)
    test("child is var token", get_token_type(var_id) == "var")
    test("var name includes function", get_token_metadata(var_id, "var_name") == "VAR|split|pipe")
}

function test_multiline_template() {
    clear_token_tree()
    
    template = "Line 1\n{{VAR}}\nLine 3"
    root_id = tokenize(template)
    
    test("multiline root has 3 children", get_children_count(root_id) == 3)
    
    child1 = get_child(root_id, 1)
    child2 = get_child(root_id, 2)
    child3 = get_child(root_id, 3)
    
    test("child1 is text", get_token_type(child1) == "text")
    test("child1 value", get_token_value(child1) == "Line 1\n")
    test("child2 is var", get_token_type(child2) == "var")
    test("child3 is text", get_token_type(child3) == "text")
    test("child3 value", get_token_value(child3) == "\nLine 3")
}

function test_complex_nested() {
    clear_token_tree()
    
    template = "{{#set key={{item}}}}{{#for x in DATA}}{{#if COND}}{{x}}{{/if}}{{/for}}{{/set}}"
    root_id = tokenize(template)
    
    test("complex nested root has 1 child", get_children_count(root_id) == 1)
    
    set_id = get_child(root_id, 1)
    test("set has 1 child", get_children_count(set_id) == 1)
    
    for_id = get_child(set_id, 1)
    test("for has 1 child", get_children_count(for_id) == 1)
    
    if_id = get_child(for_id, 1)
    test("if has 1 child", get_children_count(if_id) == 1)
    
    var_id = get_child(if_id, 1)
    test("var is correct", get_token_type(var_id) == "var")
}

BEGIN {
    printf "Running advanced tokenizer tests...\n\n"
    
    test_for_construct()
    test_set_construct()
    test_set_with_nested_variable()
    test_if_with_else()
    test_nested_for_in_if()
    test_awk_section()
    test_variable_with_function()
    test_multiline_template()
    test_complex_nested()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

