# Unit tests for renderer.awk

@include "core/token_tree.awk"
@include "core/renderer.awk"

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

function test_render_text() {
    clear_token_tree()
    
    text_id = create_token("text", "Hello", "")
    result = render_token(text_id)
    
    test("render text returns value", result == "Hello")
}

function test_render_root() {
    clear_token_tree()
    
    root_id = create_token("root", "", "")
    text1_id = create_token("text", "Hello", "")
    text2_id = create_token("text", " World", "")
    add_child(root_id, text1_id)
    add_child(root_id, text2_id)
    
    result = render_token(root_id)
    
    test("render root concatenates children", result == "Hello World")
}

function test_render_nested() {
    clear_token_tree()
    
    root_id = create_token("root", "", "")
    inner_id = create_token("root", "", "")
    text_id = create_token("text", "Hello", "")
    add_child(inner_id, text_id)
    add_child(root_id, inner_id)
    
    result = render_token(root_id)
    
    test("render nested returns value", result == "Hello")
}

function test_render_empty_root() {
    clear_token_tree()
    
    root_id = create_token("root", "", "")
    result = render_token(root_id)
    
    test("render empty root returns empty", result == "")
}

function test_render_tree() {
    clear_token_tree()
    
    root_id = create_token("root", "", "")
    text_id = create_token("text", "Hello", "")
    add_child(root_id, text_id)
    
    result = render_tree(root_id)
    
    test("render_tree returns value", result == "Hello")
}

BEGIN {
    printf "Running renderer tests...\n\n"
    
    test_render_text()
    test_render_root()
    test_render_nested()
    test_render_empty_root()
    test_render_tree()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

