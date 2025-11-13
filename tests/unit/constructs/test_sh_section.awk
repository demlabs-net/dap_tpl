# Unit test for sh_section construct
# Tests {{SH: ... }} multi-line shell sections

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/renderer.awk"
@include "constructs/sh_section/definition.awk"
@include "constructs/sh_section/evaluator.awk"

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

function test_sh_section_simple() {
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # Create SH section token with simple code
    metadata["start_line"] = 1
    sh_id = create_token("sh_section", "", metadata)
    
    # Add shell code as text child
    code_id = create_token("text", "echo \"Hello from SH\"", "")
    add_child(sh_id, code_id)
    
    # Evaluate
    result_id = evaluate_sh_section(sh_id)
    
    test("sh_section returns text token", get_token_type(result_id) == "text")
    test("sh_section produces output", get_token_value(result_id) ~ /Hello from SH/)
}

BEGIN {
    printf "Running sh_section tests...\n\n"
    
    test_sh_section_simple()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

