# Stack manager for template constructs
# Provides functions for managing the construct stack during parsing

# Stack for nested constructs (global variables)
# stack_size - current stack size
# stack[stack_size, "type"] - construct type
# stack[stack_size, "condition"] - condition/variable name
# stack[stack_size, "start_line"] - starting line number
# stack[stack_size, "brace_count"] - brace count for matching
# stack[stack_size, "content"] - accumulated content
# stack[stack_size, "in_else"] - whether we're in else block
# stack[stack_size, "else_start_line"] - else block start line
# stack[stack_size, "else_content"] - else block content

# Helper function to push construct onto stack
function push_construct(type, condition, start, brace_cnt) {
    stack_size++
    stack[stack_size, "type"] = type
    stack[stack_size, "condition"] = condition
    stack[stack_size, "start_line"] = start
    stack[stack_size, "brace_count"] = brace_cnt
    stack[stack_size, "content"] = ""
    stack[stack_size, "in_else"] = 0
    stack[stack_size, "else_start_line"] = 0
    stack[stack_size, "else_content"] = ""
}

# Helper function to pop construct from stack
function pop_construct() {
    if (stack_size > 0) {
        stack_size--
    }
}

# Helper function to get current construct type
function current_type() {
    if (stack_size > 0) {
        return stack[stack_size, "type"]
    }
    return ""
}

# Helper function to add content to current construct
function add_content(text) {
    if (stack_size > 0) {
        if (stack[stack_size, "in_else"]) {
            if (stack[stack_size, "else_content"] != "") {
                stack[stack_size, "else_content"] = stack[stack_size, "else_content"] "\n" text
            } else {
                stack[stack_size, "else_content"] = text
            }
        } else {
            if (stack[stack_size, "content"] != "") {
                stack[stack_size, "content"] = stack[stack_size, "content"] "\n" text
            } else {
                stack[stack_size, "content"] = text
            }
        }
    }
}

