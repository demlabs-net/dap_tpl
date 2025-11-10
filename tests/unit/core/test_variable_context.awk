# Unit tests for variable_context.awk

@include "core/variable_context.awk"

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

function test_push_pop_context() {
    clear_contexts()
    
    test("initial level is 0", get_current_level() == 0)
    
    level1 = push_context()
    test("push_context returns 1", level1 == 1)
    test("current level is 1", get_current_level() == 1)
    
    level2 = push_context()
    test("push_context returns 2", level2 == 2)
    test("current level is 2", get_current_level() == 2)
    
    pop_context()
    test("after pop, level is 1", get_current_level() == 1)
    
    pop_context()
    test("after second pop, level is 0", get_current_level() == 0)
}

function test_set_get_var() {
    clear_contexts()
    
    push_context()
    set_var("test_var", "test_value")
    
    test("get_var returns correct value", get_var("test_var") == "test_value")
    test("has_var returns true", has_var("test_var") == 1)
    test("has_var returns false for non-existent", has_var("nonexistent") == 0)
}

function test_variable_scoping() {
    clear_contexts()
    
    # Root context
    push_context()
    set_var("var1", "root_value")
    
    # Nested context
    push_context()
    set_var("var2", "nested_value")
    
    test("var1 accessible in nested context", get_var("var1") == "root_value")
    test("var2 accessible in nested context", get_var("var2") == "nested_value")
    
    # Shadow var1 in nested context
    set_var("var1", "nested_override")
    test("var1 shadowed in nested context", get_var("var1") == "nested_override")
    
    # Pop nested context
    pop_context()
    test("var1 restored to root value", get_var("var1") == "root_value")
    test("var2 not accessible after pop", get_var("var2") == "")
}

function test_environ_fallback() {
    clear_contexts()
    
    # Set environment variable
    ENVIRON["env_var"] = "env_value"
    
    test("get_var falls back to ENVIRON", get_var("env_var") == "env_value")
    test("has_var returns true for ENVIRON var", has_var("env_var") == 1)
}

function test_deep_nesting() {
    clear_contexts()
    
    push_context()
    set_var("level1", "1")
    
    push_context()
    set_var("level2", "2")
    
    push_context()
    set_var("level3", "3")
    
    test("level3 accessible", get_var("level3") == "3")
    test("level2 accessible", get_var("level2") == "2")
    test("level1 accessible", get_var("level1") == "1")
    
    pop_context()
    test("level3 not accessible after pop", get_var("level3") == "")
    test("level2 still accessible", get_var("level2") == "2")
    
    pop_context()
    test("level2 not accessible after pop", get_var("level2") == "")
    test("level1 still accessible", get_var("level1") == "1")
}

function test_multiple_variables() {
    clear_contexts()
    push_context()
    
    set_var("var1", "value1")
    set_var("var2", "value2")
    set_var("var3", "value3")
    
    test("var1 set", get_var("var1") == "value1")
    test("var2 set", get_var("var2") == "value2")
    test("var3 set", get_var("var3") == "value3")
    
    set_var("var2", "new_value2")
    test("var2 updated", get_var("var2") == "new_value2")
    test("var1 unchanged", get_var("var1") == "value1")
}

function test_clear_contexts() {
    clear_contexts()
    push_context()
    
    set_var("test_var", "value")
    test("var set before clear", get_var("test_var") == "value")
    
    clear_contexts()
    test("var cleared", get_var("test_var") == "")
    test("level reset to 0", get_current_level() == 0)
}

BEGIN {
    printf "Running variable_context tests...\n\n"
    
    test_push_pop_context()
    test_set_get_var()
    test_variable_scoping()
    test_environ_fallback()
    test_deep_nesting()
    test_multiple_variables()
    test_clear_contexts()
    
    printf "\nResults: %d tests, %d passed, %d failed\n", test_count, pass_count, fail_count
    
    if (fail_count == 0) {
        print "PASS"
    }
    
    exit (fail_count > 0 ? 1 : 0)
}

