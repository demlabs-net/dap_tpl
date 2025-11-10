# Parser for if constructs: {{#if VAR}}...{{/if}} and {{#if VAR}}...{{else}}...{{/if}}
# Uses stack_manager.awk functions

@include "stack_manager.awk"
@include "marker_detector.awk"

# Process if construct marker
function process_if_marker(line, line_num,    condition, remaining, result) {
    result = extract_if_condition(line)
    if (result != "") {
        split(result, parts, "|")
        condition = parts[1]
        remaining = parts[2]
        push_construct("if", condition, line_num, 2)
        if (remaining != "") {
            add_content(remaining)
        }
        return 1
    }
    return 0
}

# Process else marker
function process_else_marker(line, line_num,    remaining) {
    if (stack_size > 0 && stack[stack_size, "type"] == "if" && !stack[stack_size, "in_else"]) {
        stack[stack_size, "in_else"] = 1
        stack[stack_size, "else_start_line"] = line_num
        remaining = line
        sub(/{{else}}/, "", remaining)
        if (match(remaining, /{{(\/if|\/for|\/set|\/include)}}/)) {
            remaining = substr(remaining, 1, RSTART - 1)
        }
        if (remaining != "") {
            stack[stack_size, "else_content"] = remaining
        }
        return 1
    }
    return 0
}

