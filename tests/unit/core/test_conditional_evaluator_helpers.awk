# Unit tests for conditional_evaluator_helpers.awk
# Tests copy_main_branch_children and copy_branch_children functions

@include "core/token_tree.awk"
@include "core/child_helpers.awk"
@include "core/metadata_helpers.awk"
@include "core/conditional_evaluator_helpers.awk"

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

function test_copy_main_branch_children_excludes_else() {
    printf "\n--- Testing copy_main_branch_children excludes else ---\n"
    
    clear_token_tree()
    
    # Create source if token with children: text, if, else
    delete metadata
    source_id = create_token("if", "", metadata)
    text1_id = create_token("text", "Before", "")
    nested_if_id = create_token("if", "", metadata)
    else_id = create_token("else", "", metadata)
    text2_id = create_token("text", "After", "")
    
    add_child(source_id, text1_id)
    add_child(source_id, nested_if_id)
    add_child(source_id, else_id)
    add_child(source_id, text2_id)
    
    # Create result token
    result_id = create_token("root", "", metadata)
    
    # Copy main branch children (excluding else)
    copy_main_branch_children(source_id, result_id, "elif else")
    
    # Check result
    result_child_count = get_children_count(result_id)
    test("copy_main_branch_children excludes else: child count is 3", result_child_count == 3)
    
    # Check that else is not included
    else_found = 0
    for (i = 1; i <= result_child_count; i++) {
        child_id = get_child(result_id, i)
        if (get_token_type(child_id) == "else") {
            else_found = 1
            break
        }
    }
    test("copy_main_branch_children excludes else: else not found", else_found == 0)
    
    # Check that text and if are included
    text1_found = 0
    nested_if_found = 0
    for (i = 1; i <= result_child_count; i++) {
        child_id = get_child(result_id, i)
        child_type = get_token_type(child_id)
        if (child_id == text1_id) {
            text1_found = 1
        }
        if (child_id == nested_if_id) {
            nested_if_found = 1
        }
    }
    test("copy_main_branch_children excludes else: text1 found", text1_found == 1)
    test("copy_main_branch_children excludes else: nested_if found", nested_if_found == 1)
}

function test_copy_main_branch_children_excludes_elif_and_else() {
    printf "\n--- Testing copy_main_branch_children excludes elif and else ---\n"
    
    clear_token_tree()
    
    # Create source if token with children: text, elif, else
    delete metadata
    source_id = create_token("if", "", metadata)
    text1_id = create_token("text", "Before", "")
    elif_id = create_token("elif", "", metadata)
    else_id = create_token("else", "", metadata)
    text2_id = create_token("text", "After", "")
    
    add_child(source_id, text1_id)
    add_child(source_id, elif_id)
    add_child(source_id, else_id)
    add_child(source_id, text2_id)
    
    # Create result token
    result_id = create_token("root", "", metadata)
    
    # Copy main branch children (excluding elif and else)
    copy_main_branch_children(source_id, result_id, "elif else")
    
    # Check result
    result_child_count = get_children_count(result_id)
    test("copy_main_branch_children excludes elif and else: child count is 2", result_child_count == 2)
    
    # Check that elif and else are not included
    elif_found = 0
    else_found = 0
    for (i = 1; i <= result_child_count; i++) {
        child_id = get_child(result_id, i)
        child_type = get_token_type(child_id)
        if (child_type == "elif") {
            elif_found = 1
        }
        if (child_type == "else") {
            else_found = 1
        }
    }
    test("copy_main_branch_children excludes elif and else: elif not found", elif_found == 0)
    test("copy_main_branch_children excludes elif and else: else not found", else_found == 0)
}

function test_copy_branch_children() {
    printf "\n--- Testing copy_branch_children ---\n"
    
    clear_token_tree()
    
    # Create else branch token with children
    delete metadata
    else_id = create_token("else", "", metadata)
    text1_id = create_token("text", "Else content 1", "")
    text2_id = create_token("text", "Else content 2", "")
    var_id = create_token("var", "", metadata)
    
    add_child(else_id, text1_id)
    add_child(else_id, text2_id)
    add_child(else_id, var_id)
    
    # Create result token
    result_id = create_token("root", "", metadata)
    
    # Copy branch children
    copy_branch_children(else_id, result_id)
    
    # Check result
    result_child_count = get_children_count(result_id)
    test("copy_branch_children: child count is 3", result_child_count == 3)
    
    # Check that all children are copied
    text1_found = 0
    text2_found = 0
    var_found = 0
    for (i = 1; i <= result_child_count; i++) {
        child_id = get_child(result_id, i)
        if (child_id == text1_id) {
            text1_found = 1
        }
        if (child_id == text2_id) {
            text2_found = 1
        }
        if (child_id == var_id) {
            var_found = 1
        }
    }
    test("copy_branch_children: text1 found", text1_found == 1)
    test("copy_branch_children: text2 found", text2_found == 1)
    test("copy_branch_children: var found", var_found == 1)
}

function test_copy_main_branch_children_empty_source() {
    printf "\n--- Testing copy_main_branch_children with empty source ---\n"
    
    clear_token_tree()
    
    # Create empty source token
    delete metadata
    source_id = create_token("if", "", metadata)
    
    # Create result token
    result_id = create_token("root", "", metadata)
    
    # Copy main branch children
    copy_main_branch_children(source_id, result_id, "elif else")
    
    # Check result
    result_child_count = get_children_count(result_id)
    test("copy_main_branch_children empty source: child count is 0", result_child_count == 0)
}

function test_copy_branch_children_empty_branch() {
    printf "\n--- Testing copy_branch_children with empty branch ---\n"
    
    clear_token_tree()
    
    # Create empty else branch token
    delete metadata
    else_id = create_token("else", "", metadata)
    
    # Create result token
    result_id = create_token("root", "", metadata)
    
    # Copy branch children
    copy_branch_children(else_id, result_id)
    
    # Check result
    result_child_count = get_children_count(result_id)
    test("copy_branch_children empty branch: child count is 0", result_child_count == 0)
}

function test_copy_main_branch_children_preserves_order() {
    printf "\n--- Testing copy_main_branch_children preserves order ---\n"
    
    clear_token_tree()
    
    # Create source if token with children in specific order
    delete metadata
    source_id = create_token("if", "", metadata)
    text1_id = create_token("text", "First", "")
    text2_id = create_token("text", "Second", "")
    else_id = create_token("else", "", metadata)
    text3_id = create_token("text", "Third", "")
    
    add_child(source_id, text1_id)
    add_child(source_id, text2_id)
    add_child(source_id, else_id)
    add_child(source_id, text3_id)
    
    # Create result token
    result_id = create_token("root", "", metadata)
    
    # Copy main branch children (excluding else)
    copy_main_branch_children(source_id, result_id, "elif else")
    
    # Check result order
    result_child_count = get_children_count(result_id)
    test("copy_main_branch_children preserves order: child count is 3", result_child_count == 3)
    
    # Check order: text1, text2, text3 (else excluded)
    first_child = get_child(result_id, 1)
    second_child = get_child(result_id, 2)
    third_child = get_child(result_id, 3)
    
    test("copy_main_branch_children preserves order: first is text1", first_child == text1_id)
    test("copy_main_branch_children preserves order: second is text2", second_child == text2_id)
    test("copy_main_branch_children preserves order: third is text3", third_child == text3_id)
}

BEGIN {
    printf "Running conditional_evaluator_helpers tests...\n\n"
    
    test_copy_main_branch_children_excludes_else()
    test_copy_main_branch_children_excludes_elif_and_else()
    test_copy_branch_children()
    test_copy_main_branch_children_empty_source()
    test_copy_branch_children_empty_branch()
    test_copy_main_branch_children_preserves_order()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

