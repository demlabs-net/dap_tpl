# Unit tests for nested if conditions
# Tests evaluate_if with nested conditions, especially in for loop context

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"
@include "core/condition_parser.awk"
@include "core/construct_registry.awk"
@include "constructs/if/definition.awk"
@include "constructs/for/definition.awk"
@include "constructs/set/definition.awk"
@include "constructs/if/branch_parser.awk"
@include "constructs/if/evaluator.awk"
@include "constructs/for/evaluator.awk"
@include "constructs/set/evaluator.awk"
@include "constructs/var/evaluator.awk"

# Include dispatch function stubs for tests

@include "core/evaluator_core.awk"

# For full pipeline test
@include "core/tokenizer_core.awk"
@include "core/renderer.awk"
@include "constructs/if/tokenizer.awk"
@include "constructs/for/tokenizer.awk"
@include "constructs/set/tokenizer.awk"
@include "constructs/var/tokenizer.awk"
@include "constructs/text/definition.awk"
@include "constructs/text/process.awk"
@include "constructs/text/render.awk"
@include "constructs/root/definition.awk"
@include "constructs/root/render.awk"
@include "constructs/var/definition.awk"
@include "constructs/var/render.awk"

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

function test_nested_if_with_type_comparison() {
    printf "\n--- Testing nested if with type comparison ---\n"
    
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # Set up context: type="int", macro_name="int"
    set_var("type", "int")
    ENVIRON["type"] = "int"
    set_var("macro_name", "int")
    ENVIRON["macro_name"] = "int"
    
    # Create outer if token: {{#if macro_name}}
    delete metadata
    metadata["condition"] = "macro_name"
    outer_if_id = create_token("if", "", metadata)
    
    # Create inner if token: {{#if type == 'void'}}
    delete metadata
    metadata["condition"] = "type == 'void'"
    inner_if_id = create_token("if", "", metadata)
    
    # Create inner if branches
    inner_if_void_text = create_token("text", "VOID: ", "")
    inner_if_void_var = create_token("var", "", metadata)
    set_token_metadata(inner_if_void_var, "var_name", "type")
    
    inner_if_else = create_token("else", "", metadata)
    inner_if_nonvoid_text = create_token("text", "NON-VOID: ", "")
    inner_if_nonvoid_var = create_token("var", "", metadata)
    set_token_metadata(inner_if_nonvoid_var, "var_name", "type")
    
    # Add children to inner if
    add_child(inner_if_id, inner_if_void_text)
    add_child(inner_if_id, inner_if_void_var)
    add_child(inner_if_id, inner_if_else)
    add_child(inner_if_else, inner_if_nonvoid_text)
    add_child(inner_if_else, inner_if_nonvoid_var)
    
    # Add inner if to outer if
    add_child(outer_if_id, inner_if_id)
    
    # Evaluate outer if
    outer_result_id = evaluate_if(outer_if_id)
    
    # Check that outer if has children (because macro_name is truthy)
    outer_child_count = get_children_count(outer_result_id)
    test("nested if: outer if has children", outer_child_count > 0)
    
    # Evaluate inner if (should be in outer result)
    inner_result_id = 0
    for (i = 1; i <= outer_child_count; i++) {
        child_id = get_child(outer_result_id, i)
        if (get_token_type(child_id) == "if") {
            inner_result_id = child_id
            break
        }
    }
    test("nested if: inner if found in outer result", inner_result_id > 0)
    
    if (inner_result_id > 0) {
        # Evaluate inner if
        inner_evaluated_id = evaluate_if(inner_result_id)
        inner_child_count = get_children_count(inner_evaluated_id)
        
        # Check that inner if has children (from else branch, because type != 'void')
        test("nested if: inner if has children", inner_child_count > 0)
        
        # Check that inner if result contains "NON-VOID" text
        nonvoid_found = 0
        void_found = 0
        for (i = 1; i <= inner_child_count; i++) {
            child_id = get_child(inner_evaluated_id, i)
            child_type = get_token_type(child_id)
            if (child_type == "text") {
                child_value = get_token_value(child_id)
                if (child_value == "NON-VOID: ") {
                    nonvoid_found = 1
                }
                if (child_value == "VOID: ") {
                    void_found = 1
                }
            }
        }
        test("nested if: NON-VOID branch found", nonvoid_found == 1)
        test("nested if: VOID branch NOT found", void_found == 0)
    }
}

function test_nested_if_with_void_type() {
    printf "\n--- Testing nested if with void type ---\n"
    
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # Set up context: type="void", macro_name="void"
    set_var("type", "void")
    ENVIRON["type"] = "void"
    set_var("macro_name", "void")
    ENVIRON["macro_name"] = "void"
    
    # Create outer if token: {{#if macro_name}}
    delete metadata
    metadata["condition"] = "macro_name"
    outer_if_id = create_token("if", "", metadata)
    
    # Create inner if token: {{#if type == 'void'}}
    delete metadata
    metadata["condition"] = "type == 'void'"
    inner_if_id = create_token("if", "", metadata)
    
    # Create inner if branches
    inner_if_void_text = create_token("text", "VOID: ", "")
    inner_if_void_var = create_token("var", "", metadata)
    set_token_metadata(inner_if_void_var, "var_name", "type")
    
    inner_if_else = create_token("else", "", metadata)
    inner_if_nonvoid_text = create_token("text", "NON-VOID: ", "")
    inner_if_nonvoid_var = create_token("var", "", metadata)
    set_token_metadata(inner_if_nonvoid_var, "var_name", "type")
    
    # Add children to inner if
    add_child(inner_if_id, inner_if_void_text)
    add_child(inner_if_id, inner_if_void_var)
    add_child(inner_if_id, inner_if_else)
    add_child(inner_if_else, inner_if_nonvoid_text)
    add_child(inner_if_else, inner_if_nonvoid_var)
    
    # Add inner if to outer if
    add_child(outer_if_id, inner_if_id)
    
    # Evaluate outer if
    outer_result_id = evaluate_if(outer_if_id)
    
    # Evaluate inner if (should be in outer result)
    outer_child_count = get_children_count(outer_result_id)
    inner_result_id = 0
    for (i = 1; i <= outer_child_count; i++) {
        child_id = get_child(outer_result_id, i)
        if (get_token_type(child_id) == "if") {
            inner_result_id = child_id
            break
        }
    }
    
    if (inner_result_id > 0) {
        # Evaluate inner if
        inner_evaluated_id = evaluate_if(inner_result_id)
        inner_child_count = get_children_count(inner_evaluated_id)
        
        # Check that inner if result contains "VOID" text
        void_found = 0
        nonvoid_found = 0
        for (i = 1; i <= inner_child_count; i++) {
            child_id = get_child(inner_evaluated_id, i)
            child_type = get_token_type(child_id)
            if (child_type == "text") {
                child_value = get_token_value(child_id)
                if (child_value == "VOID: ") {
                    void_found = 1
                }
                if (child_value == "NON-VOID: ") {
                    nonvoid_found = 1
                }
            }
        }
        test("nested if void: VOID branch found", void_found == 1)
        test("nested if void: NON-VOID branch NOT found", nonvoid_found == 0)
    }
}

function test_nested_if_in_for_loop_real_world() {
    printf "\n--- Testing nested if in for loop (real-world scenario) ---\n"
    
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # Set up context: RETURN_TYPES="void int"
    set_var("RETURN_TYPES", "void int")
    ENVIRON["RETURN_TYPES"] = "void int"
    
    # Create for token: {{#for type in RETURN_TYPES}}
    delete metadata
    metadata["condition"] = "type in RETURN_TYPES"
    for_id = create_token("for", "", metadata)
    
    # Create set token: {{#set macro_name={{type|sanitize_name}}}}
    delete metadata
    metadata["condition"] = "macro_name={{type|sanitize_name}}"
    set_id = create_token("set", "", metadata)
    
    # Create outer if token: {{#if macro_name}}
    delete metadata
    metadata["condition"] = "macro_name"
    outer_if_id = create_token("if", "", metadata)
    
    # Create inner if token: {{#if type == 'void'}}
    delete metadata
    metadata["condition"] = "type == 'void'"
    inner_if_id = create_token("if", "", metadata)
    
    # Create inner if branches
    inner_if_void_text = create_token("text", "VOID: ", "")
    inner_if_void_var = create_token("var", "", metadata)
    set_token_metadata(inner_if_void_var, "var_name", "type")
    
    inner_if_else = create_token("else", "", metadata)
    inner_if_nonvoid_text = create_token("text", "NON-VOID: ", "")
    inner_if_nonvoid_var = create_token("var", "", metadata)
    set_token_metadata(inner_if_nonvoid_var, "var_name", "type")
    
    # Add children to inner if
    add_child(inner_if_id, inner_if_void_text)
    add_child(inner_if_id, inner_if_void_var)
    add_child(inner_if_id, inner_if_else)
    add_child(inner_if_else, inner_if_nonvoid_text)
    add_child(inner_if_else, inner_if_nonvoid_var)
    
    # Add inner if to outer if
    add_child(outer_if_id, inner_if_id)
    
    # Add outer if to set
    add_child(set_id, outer_if_id)
    
    # Add set to for
    add_child(for_id, set_id)
    
    # Evaluate for loop (this should evaluate set, outer_if, and inner_if for each iteration)
    for_result_id = evaluate_for(for_id)
    
    # Check that for result has children (2 iterations: void and int)
    for_child_count = get_children_count(for_result_id)
    test("for loop: has 2 iterations", for_child_count == 2)
    
    # Check first iteration (void)
    if (for_child_count >= 1) {
        first_iter_id = get_child(for_result_id, 1)
        first_iter_type = get_token_type(first_iter_id)
        first_iter_children = get_children_count(first_iter_id)
        # Debug output - always print when test fails
        if (first_iter_type != "root") {
            printf "DEBUG test: first_iter_id=%d type=%s children=%d (expected root)\n", first_iter_id, first_iter_type, first_iter_children > "/dev/stderr"
            # Check what children are
            for (k = 1; k <= first_iter_children && k <= 3; k++) {
                child_check_id = get_child(first_iter_id, k)
                child_check_type = get_token_type(child_check_id)
                child_check_children = get_children_count(child_check_id)
                printf "DEBUG test:   child[%d]=%d type=%s children=%d\n", k, child_check_id, child_check_type, child_check_children > "/dev/stderr"
            }
        }
        test("for loop: first iteration is root (from set)", first_iter_type == "root")
        
        # Find inner if result in first iteration
        first_iter_child_count = get_children_count(first_iter_id)
        inner_if_result_found = 0
        inner_if_result_id = 0
        
        # Search recursively for inner if result
        for (i = 1; i <= first_iter_child_count; i++) {
            child_id = get_child(first_iter_id, i)
            child_type = get_token_type(child_id)
            if (child_type == "if") {
                # This might be the inner if result
                inner_if_result_id = child_id
                inner_if_result_found = 1
                break
            }
            # Check children recursively
            if (get_children_count(child_id) > 0) {
                for (j = 1; j <= get_children_count(child_id); j++) {
                    grandchild_id = get_child(child_id, j)
                    if (get_token_type(grandchild_id) == "if") {
                        inner_if_result_id = grandchild_id
                        inner_if_result_found = 1
                        break
                    }
                }
            }
            if (inner_if_result_found) break
        }
        
        if (inner_if_result_found && inner_if_result_id > 0) {
            # Evaluate inner if result to get final children
            inner_evaluated_id = evaluate_if(inner_if_result_id)
            inner_child_count = get_children_count(inner_evaluated_id)
            
            # Check that inner if result contains "VOID" text for first iteration
            void_found = 0
            nonvoid_found = 0
            for (i = 1; i <= inner_child_count; i++) {
                child_id = get_child(inner_evaluated_id, i)
                child_type = get_token_type(child_id)
                if (child_type == "text") {
                    child_value = get_token_value(child_id)
                    if (child_value == "VOID: ") {
                        void_found = 1
                    }
                    if (child_value == "NON-VOID: ") {
                        nonvoid_found = 1
                    }
                }
            }
            test("for loop void iteration: VOID branch found", void_found == 1)
            test("for loop void iteration: NON-VOID branch NOT found", nonvoid_found == 0)
        }
    }
    
    # Check second iteration (int)
    if (for_child_count >= 2) {
        second_iter_id = get_child(for_result_id, 2)
        second_iter_type = get_token_type(second_iter_id)
        test("for loop: second iteration is root (from set)", second_iter_type == "root")
        
        # Find inner if result in second iteration
        second_iter_child_count = get_children_count(second_iter_id)
        inner_if_result_found = 0
        inner_if_result_id = 0
        
        # Search recursively for inner if result
        for (i = 1; i <= second_iter_child_count; i++) {
            child_id = get_child(second_iter_id, i)
            child_type = get_token_type(child_id)
            if (child_type == "if") {
                inner_if_result_id = child_id
                inner_if_result_found = 1
                break
            }
            # Check children recursively
            if (get_children_count(child_id) > 0) {
                for (j = 1; j <= get_children_count(child_id); j++) {
                    grandchild_id = get_child(child_id, j)
                    if (get_token_type(grandchild_id) == "if") {
                        inner_if_result_id = grandchild_id
                        inner_if_result_found = 1
                        break
                    }
                }
            }
            if (inner_if_result_found) break
        }
        
        if (inner_if_result_found && inner_if_result_id > 0) {
            # Evaluate inner if result to get final children
            inner_evaluated_id = evaluate_if(inner_if_result_id)
            inner_child_count = get_children_count(inner_evaluated_id)
            
            # Check that inner if result contains "NON-VOID" text for second iteration
            void_found = 0
            nonvoid_found = 0
            for (i = 1; i <= inner_child_count; i++) {
                child_id = get_child(inner_evaluated_id, i)
                child_type = get_token_type(child_id)
                if (child_type == "text") {
                    child_value = get_token_value(child_id)
                    if (child_value == "VOID: ") {
                        void_found = 1
                    }
                    if (child_value == "NON-VOID: ") {
                        nonvoid_found = 1
                    }
                }
            }
            test("for loop int iteration: NON-VOID branch found", nonvoid_found == 1)
            test("for loop int iteration: VOID branch NOT found", void_found == 0)
        }
    }
}

function test_nested_if_in_for_loop_with_full_evaluation() {
    printf "\n--- Testing nested if in for loop with full evaluation pipeline ---\n"
    
    # This test uses tokenize/evaluate_tree/render_tree to fully simulate real-world scenario
    # Template structure: {{#for type in RETURN_TYPES}}{{#set macro_name={{type|sanitize_name}}}}{{#if macro_name}}{{#if type == 'void'}}VOID{{else}}NON-VOID{{/if}}{{/if}}{{/for}}
    
    clear_token_tree()
    clear_contexts()
    push_context()
    
    # Set up context: RETURN_TYPES="void int"
    set_var("RETURN_TYPES", "void int")
    ENVIRON["RETURN_TYPES"] = "void int"
    
    # Create template string that matches real-world scenario
    template = "{{#for type in RETURN_TYPES}}\n{{#set macro_name={{type|sanitize_name}}}}\n{{#if macro_name}}\n{{#if type == 'void'}}\nVOID: {{type}}\n{{else}}\nNON-VOID: {{type}}\n{{/if}}\n{{/if}}\n{{/for}}"
    
    # Tokenize template
    root_id = tokenize(template)
    test("full pipeline: tokenization succeeded", root_id > 0)
    
    if (root_id > 0) {
        # Evaluate tree
        eval_root_id = evaluate_tree(root_id)
        test("full pipeline: evaluation succeeded", eval_root_id > 0)
        
        if (eval_root_id > 0) {
            # Render tree
            output = render_tree(eval_root_id)
            test("full pipeline: rendering succeeded", output != "")
            
            # Check output
            # Should contain "VOID: void" exactly once
            void_count = gsub(/VOID: void/, "&", output)
            test("full pipeline: VOID: void appears exactly once", void_count == 1)
            
            # Should contain "NON-VOID: int" exactly once
            nonvoid_count = gsub(/NON-VOID: int/, "&", output)
            test("full pipeline: NON-VOID: int appears exactly once", nonvoid_count == 1)
            
            # Should NOT contain "VOID: int" (on a single line, not across lines)
            # Check each line separately to avoid false positives from multiline matches
            void_int_found = 0
            split(output, lines, "\n")
            for (line_idx in lines) {
                if (lines[line_idx] ~ /^[[:space:]]*VOID:[[:space:]]+int[[:space:]]*$/) {
                    void_int_found = 1
                    printf "DEBUG: Found VOID: int on line %d: [%s]\n", line_idx, lines[line_idx] > "/dev/stderr"
                    break
                }
            }
            test("full pipeline: VOID: int does NOT appear", void_int_found == 0)
            
            # Should NOT contain "NON-VOID: void"
            nonvoid_void_found = (output ~ /NON-VOID: void/)
            test("full pipeline: NON-VOID: void does NOT appear", nonvoid_void_found == 0)
            
            # Debug output (only if test fails)
            if (output == "" || void_int_found || nonvoid_void_found || void_count != 1 || nonvoid_count != 1) {
                # Debug output goes to stderr, but only if DEBUG_ENABLED is set
                # In unit tests, we don't want debug output unless explicitly enabled
                # Always print debug output when test fails, regardless of DEBUG_ENABLED
                printf "DEBUG: Output was:\n%s\n", output > "/dev/stderr"
                printf "DEBUG: Output length: %d\n", length(output) > "/dev/stderr"
                printf "DEBUG: eval_root_id: %d\n", eval_root_id > "/dev/stderr"
                printf "DEBUG: eval_root type: %s\n", get_token_type(eval_root_id) > "/dev/stderr"
                printf "DEBUG: eval_root children: %d\n", get_children_count(eval_root_id) > "/dev/stderr"
                
                # Debug: check children types and rendering
                child_count = get_children_count(eval_root_id)
                for (i = 1; i <= child_count && i <= 5; i++) {
                    child_id = get_child(eval_root_id, i)
                    child_type = get_token_type(child_id)
                    child_value = get_token_value(child_id)
                    child_children = get_children_count(child_id)
                    skip_empty = get_token_metadata(child_id, "skip_empty_text")
                    # Test rendering this child
                    child_rendered = render_token(child_id)
                    printf "DEBUG: child[%d]: type=%s value=[%s] children=%d skip_empty=%s rendered=[%s]\n", i, child_type, child_value, child_children, skip_empty, child_rendered > "/dev/stderr"
                    
                    # Debug grandchildren of root child
                    if (child_type == "root" && child_children > 0) {
                        printf "DEBUG:   root child[%d] has %d grandchildren:\n", i, child_children > "/dev/stderr"
                        for (k = 1; k <= child_children && k <= 5; k++) {
                            grandchild_id = get_child(child_id, k)
                            grandchild_type = get_token_type(grandchild_id)
                            grandchild_value = get_token_value(grandchild_id)
                            grandchild_children = get_children_count(grandchild_id)
                            grandchild_rendered = render_token(grandchild_id)
                            printf "DEBUG:     grandchild[%d]: type=%s value=[%s] children=%d rendered=[%s]\n", k, grandchild_type, grandchild_value, grandchild_children, grandchild_rendered > "/dev/stderr"
                            
                            # Debug great-grandchildren for root grandchildren
                            if (grandchild_type == "root" && grandchild_children > 0) {
                                printf "DEBUG:       root grandchild[%d] has %d great-grandchildren:\n", k, grandchild_children > "/dev/stderr"
                                for (m = 1; m <= grandchild_children && m <= 5; m++) {
                                    great_grandchild_id = get_child(grandchild_id, m)
                                    great_grandchild_type = get_token_type(great_grandchild_id)
                                    great_grandchild_value = get_token_value(great_grandchild_id)
                                    great_grandchild_children = get_children_count(great_grandchild_id)
                                    great_grandchild_rendered = render_token(great_grandchild_id)
                                    printf "DEBUG:         great-grandchild[%d]: type=%s value=[%s] children=%d rendered=[%s]\n", m, great_grandchild_type, great_grandchild_value, great_grandchild_children, great_grandchild_rendered > "/dev/stderr"
                                    
                                    # Debug great-great-grandchildren for root great-grandchildren
                                    if (great_grandchild_type == "root" && great_grandchild_children > 0) {
                                        printf "DEBUG:           root great-grandchild[%d] has %d great-great-grandchildren:\n", m, great_grandchild_children > "/dev/stderr"
                                        for (n = 1; n <= great_grandchild_children && n <= 5; n++) {
                                            great_great_grandchild_id = get_child(great_grandchild_id, n)
                                            great_great_grandchild_type = get_token_type(great_great_grandchild_id)
                                            great_great_grandchild_value = get_token_value(great_great_grandchild_id)
                                            great_great_grandchild_children = get_children_count(great_great_grandchild_id)
                                            great_great_grandchild_rendered = render_token(great_great_grandchild_id)
                                            printf "DEBUG:             great-great-grandchild[%d]: type=%s value=[%s] value_length=%d children=%d rendered=[%s] rendered_length=%d\n", n, great_great_grandchild_type, great_great_grandchild_value, length(great_great_grandchild_value), great_great_grandchild_children, great_great_grandchild_rendered, length(great_great_grandchild_rendered) > "/dev/stderr"
                                            
                                            # Debug var tokens
                                            if (great_great_grandchild_type == "var") {
                                                var_name = get_token_metadata(great_great_grandchild_id, "var_name")
                                                var_value = get_var(var_name)
                                                printf "DEBUG:               var token var_name=[%s] get_var=[%s] ENVIRON[%s]=[%s]\n", var_name, var_value, var_name, ENVIRON[var_name] > "/dev/stderr"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    # Check grandchildren
                    if (child_children > 0 && child_children <= 3) {
                        for (j = 1; j <= child_children; j++) {
                            grandchild_id = get_child(child_id, j)
                            grandchild_type = get_token_type(grandchild_id)
                            grandchild_value = get_token_value(grandchild_id)
                            grandchild_rendered = render_token(grandchild_id)
                            printf "DEBUG:   grandchild[%d]: type=%s value=[%s] rendered=[%s]\n", j, grandchild_type, grandchild_value, grandchild_rendered > "/dev/stderr"
                        }
                    }
                }
            }
        }
    }
}

# Helper function for hex dump
function ord(c) {
    return sprintf("%d", c)
}

BEGIN {
    printf "Running nested if evaluator tests...\n\n"
    
    test_nested_if_with_type_comparison()
    test_nested_if_with_void_type()
    test_nested_if_in_for_loop_real_world()
    test_nested_if_in_for_loop_with_full_evaluation()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

