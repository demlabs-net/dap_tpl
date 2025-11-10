# Integration unit test: nested for in if with file-based data
# Tests complex scenario: {{#if}} → {{#for}} → {{#set}} with functions

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

function test_nested_for_in_if_with_set() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # Simulate file-based data (newline separated)
    set_var("NORMALIZATION_MACROS_DATA", "dap_list_t*|dap_list_t\nint|int\nchar*|char")
    ENVIRON["NORMALIZATION_MACROS_DATA"] = "dap_list_t*|dap_list_t\nint|int\nchar*|char"
    
    template = "{{#if NORMALIZATION_MACROS_DATA}}{{#for entry in NORMALIZATION_MACROS_DATA}}{{entry|split|pipe}}{{#set macro_key={{entry|part|0}}}}{{#set base_type={{entry|part|1}}}}Macro: {{macro_key}}, Type: {{base_type}}{{/for}}{{/if}}"
    
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("nested for in if with set produces output", length(result) > 0)
    test("result contains macro_key", result ~ /macro_key|Macro/)
    test("result contains base_type", result ~ /base_type|Type/)
    test("result contains dap_list_t", result ~ /dap_list_t/)
    test("result contains int", result ~ /int/)
    test("result contains char", result ~ /char/)
}

function test_set_with_split_and_part() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("entry", "key|value|data")
    ENVIRON["entry"] = "key|value|data"
    
    template = "{{entry|split|pipe}}{{#set key={{entry|part|0}}}}{{#set val={{entry|part|1}}}}{{key}}={{val}}"
    
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("set with split and part produces output", length(result) > 0)
    test("result contains key", result ~ /key/)
    test("result contains value", result ~ /value/)
}

function test_multiple_set_in_for() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    set_var("DATA", "a|A\nb|B\nc|C")
    ENVIRON["DATA"] = "a|A\nb|B\nc|C"
    
    template = "{{#for item in DATA}}{{item|split|pipe}}{{#set key={{item|part|0}}}}{{#set val={{item|part|1}}}}{{key}}:{{val}}{{/for}}"
    
    root_id = tokenize(template)
    evaluated_id = evaluate_tree(root_id)
    result = render_tree(evaluated_id)
    
    test("multiple set in for produces output", length(result) > 0)
    test("result contains a:A", result ~ /a.*A/ || result ~ /a:A/)
    test("result contains b:B", result ~ /b.*B/ || result ~ /b:B/)
    test("result contains c:C", result ~ /c.*C/ || result ~ /c:C/)
}

BEGIN {
    printf "Running integration unit tests...\n\n"
    
    test_nested_for_in_if_with_set()
    test_set_with_split_and_part()
    test_multiple_set_in_for()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

