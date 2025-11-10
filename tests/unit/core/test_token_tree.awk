# Unit tests for token_tree.awk

@include "core/token_tree.awk"

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

function test_create_token() {
    clear_token_tree()
    
    metadata["condition"] = "VAR"
    metadata["start_line"] = 1
    id1 = create_token("if", "", metadata)
    
    test("create_token returns positive ID", id1 > 0)
    test("token exists", token_exists(id1))
    test("token type is 'if'", get_token_type(id1) == "if")
    test("token metadata condition", get_token_metadata(id1, "condition") == "VAR")
    test("token metadata start_line", get_token_metadata(id1, "start_line") == 1)
}

function test_add_child() {
    clear_token_tree()
    
    id1 = create_token("if", "", "")
    id2 = create_token("text", "Hello", "")
    
    add_child(id1, id2)
    
    test("child count is 1", get_children_count(id1) == 1)
    test("get_child returns correct ID", get_child(id1, 1) == id2)
}

function test_clone_subtree() {
    clear_token_tree()
    
    metadata["condition"] = "VAR"
    id1 = create_token("if", "", metadata)
    id2 = create_token("text", "Hello", "")
    id3 = create_token("text", "World", "")
    
    add_child(id1, id2)
    add_child(id1, id3)
    
    id4 = clone_subtree(id1)
    
    test("clone returns new ID", id4 != id1)
    test("clone has same type", get_token_type(id4) == "if")
    test("clone has same metadata", get_token_metadata(id4, "condition") == "VAR")
    test("clone has 2 children", get_children_count(id4) == 2)
    
    child1 = get_child(id4, 1)
    child2 = get_child(id4, 2)
    test("clone child1 has correct value", get_token_value(child1) == "Hello")
    test("clone child2 has correct value", get_token_value(child2) == "World")
}

function test_token_value() {
    clear_token_tree()
    
    id1 = create_token("text", "Hello", "")
    
    test("get_token_value returns correct value", get_token_value(id1) == "Hello")
    
    set_token_value(id1, "World")
    test("set_token_value updates value", get_token_value(id1) == "World")
}

function test_multiple_children() {
    clear_token_tree()
    
    parent_id = create_token("root", "", "")
    child1 = create_token("text", "A", "")
    child2 = create_token("text", "B", "")
    child3 = create_token("text", "C", "")
    
    add_child(parent_id, child1)
    add_child(parent_id, child2)
    add_child(parent_id, child3)
    
    test("multiple children count", get_children_count(parent_id) == 3)
    test("get_child(1) correct", get_child(parent_id, 1) == child1)
    test("get_child(2) correct", get_child(parent_id, 2) == child2)
    test("get_child(3) correct", get_child(parent_id, 3) == child3)
}

function test_deep_clone() {
    clear_token_tree()
    
    root_id = create_token("if", "", "")
    level1 = create_token("for", "", "")
    level2 = create_token("text", "Deep", "")
    
    add_child(root_id, level1)
    add_child(level1, level2)
    
    cloned_id = clone_subtree(root_id)
    
    test("deep clone returns new ID", cloned_id != root_id)
    test("deep clone has child", get_children_count(cloned_id) == 1)
    
    cloned_level1 = get_child(cloned_id, 1)
    test("deep clone level1 is new", cloned_level1 != level1)
    test("deep clone level1 has child", get_children_count(cloned_level1) == 1)
    
    cloned_level2 = get_child(cloned_level1, 1)
    test("deep clone level2 is new", cloned_level2 != level2)
    test("deep clone level2 value", get_token_value(cloned_level2) == "Deep")
}

function test_metadata_operations() {
    clear_token_tree()
    
    id1 = create_token("if", "", "")
    
    set_token_metadata(id1, "condition", "VAR")
    set_token_metadata(id1, "start_line", "5")
    
    test("metadata condition", get_token_metadata(id1, "condition") == "VAR")
    test("metadata start_line", get_token_metadata(id1, "start_line") == "5")
    test("metadata nonexistent", get_token_metadata(id1, "nonexistent") == "")
    
    set_token_metadata(id1, "condition", "NEW_VAR")
    test("metadata update", get_token_metadata(id1, "condition") == "NEW_VAR")
}

BEGIN {
    printf "Running token_tree tests...\n\n"
    
    test_create_token()
    test_add_child()
    test_clone_subtree()
    test_token_value()
    test_multiple_children()
    test_deep_clone()
    test_metadata_operations()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

