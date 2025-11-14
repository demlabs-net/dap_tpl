# Unit test for set inside for loop
# Tests that {{#set}} inside {{#for}} properly preserves values

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/construct_registry.awk"
@include "core/tokenizer_core.awk"
@include "core/renderer.awk"
@include "core/evaluator_core.awk"
@include "core/variable_functions.awk"
@include "core/condition_parser.awk"
@include "core/marker_parser.awk"
@include "core/conditional_evaluator_helpers.awk"
@include "constructs/for/definition.awk"
@include "constructs/for/tokenizer.awk"
@include "constructs/for/evaluator.awk"
@include "constructs/set/definition.awk"
@include "constructs/set/tokenizer.awk"
@include "constructs/set/evaluator.awk"
@include "constructs/set/render.awk"
@include "constructs/set/process.awk"
@include "constructs/text/definition.awk"
@include "constructs/text/render.awk"
@include "constructs/text/process.awk"
@include "constructs/text/helpers.awk"
@include "constructs/root/definition.awk"
@include "constructs/root/render.awk"
@include "constructs/var/definition.awk"
@include "constructs/var/tokenizer.awk"
@include "constructs/var/evaluator.awk"
@include "constructs/var/render.awk"
@include "conditions/condition_loader.awk"
@include "tests/fixtures/dispatch_stubs.awk"

BEGIN {
    test_count = 0
    pass_count = 0
}

function test(name, condition) {
    test_count++
    if (condition) {
        pass_count++
        printf "PASS: %s\n", name
    } else {
        printf "FAIL: %s\n", name
    }
}

function test_set_outside_for() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    template = "{{#set VAR=initial}}\nValue: {{VAR}}"
    
    root = tokenize(template)
    eval_root = evaluate_tree(root)
    output = render_tree(eval_root)
    
    test("set outside for works", output ~ /Value: initial/)
}

function test_set_inside_for() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # CRITICAL TEST: set inside for should work
    template = "{{#set RESULT=}}\n{{#for item in a|b|c}}\n{{#set RESULT={{RESULT}}{{item}}}}\n{{/for}}\nResult: {{RESULT}}"
    
    root = tokenize(template)
    eval_root = evaluate_tree(root)
    output = render_tree(eval_root)
    
    print "DEBUG output: [" output "]"
    print "DEBUG RESULT var: [" get_var("RESULT") "]"
    
    # This test FAILS due to push_context/pop_context wiping variables
    test("set inside for preserves values", output ~ /Result: abc/)
}

function test_set_loop_variable_inside_for() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # Test setting loop variable inside loop
    template = "{{#for item in a|b|c}}\n{{#set item_copy={{item}}}}\nCopy: {{item_copy}}\n{{/for}}"
    
    root = tokenize(template)
    eval_root = evaluate_tree(root)
    output = render_tree(eval_root)
    
    test("set loop variable works", output ~ /Copy: a/ && output ~ /Copy: b/ && output ~ /Copy: c/)
}

BEGIN {
    printf "Running set_in_for tests...\n\n"
    
    test_set_outside_for()
    test_set_inside_for()
    test_set_loop_variable_inside_for()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, (test_count - pass_count)
    
    if (test_count == pass_count) {
        print "PASS"
        exit 0
    } else {
        print "FAIL"
        exit 1
    }
}

