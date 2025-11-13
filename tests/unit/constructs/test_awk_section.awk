# Unit test for awk_section construct
# Tests {{AWK: ... }} multi-line AWK sections

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/renderer.awk"
@include "constructs/awk_section/definition.awk"
@include "constructs/awk_section/evaluator.awk"

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

function test_awk_section_simple() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # Create AWK section token with simple code
    metadata["start_line"] = 1
    awk_id = create_token("awk_section", "", metadata)
    
    # Add AWK code as text child
    code_id = create_token("text", "BEGIN { print \"Hello from AWK\" }", "")
    add_child(awk_id, code_id)
    
    # Evaluate
    result_id = evaluate_awk_section(awk_id)
    
    test("awk_section returns text token", get_token_type(result_id) == "text")
    test("awk_section produces output", get_token_value(result_id) ~ /Hello from AWK/)
}

BEGIN {
    printf "Running awk_section tests...\n\n"
    
    test_awk_section_simple()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

