# Parser for closing tags: {{/if}}, {{/for}}, {{/set}}, {{/include}}
# Uses stack_manager.awk and marker_detector.awk functions

@include "stack_manager.awk"
@include "marker_detector.awk"

# Process closing tag
function process_closing_tag(line, line_num,    closing_type, current, brace_count, i, char, remaining, type, condition, start, content, in_else, else_start, else_content, else_end_line) {
    if (stack_size > 0) {
        closing_type = extract_closing_type(line)
        if (closing_type == "") {
            return 0
        }
        
        current = current_type()
        if (closing_type == current) {
            brace_count = stack[stack_size, "brace_count"]
            for (i = 1; i <= length(line); i++) {
                char = substr(line, i, 1)
                if (char == "{") brace_count++
                else if (char == "}") brace_count--
            }
            
            if (brace_count == 2) {
                remaining = line
                sub(/{{(\/if|\/for|\/set|\/include)}}.*$/, "", remaining)
                
                type = stack[stack_size, "type"]
                condition = stack[stack_size, "condition"]
                start = stack[stack_size, "start_line"]
                content = stack[stack_size, "content"]
                in_else = stack[stack_size, "in_else"]
                else_start = stack[stack_size, "else_start_line"]
                else_content = stack[stack_size, "else_content"]
                
                if (type == "if" && in_else && else_content != "") {
                    if (match(else_content, /{{(\/if|\/for|\/set|\/include)}}/)) {
                        else_content = substr(else_content, 1, RSTART - 1)
                        gsub(/[\001\n\r\s]+$/, "", else_content)
                    }
                }
                
                if (remaining != "") {
                    if (type == "if" && in_else) {
                        if (remaining !~ /{{(\/if|\/for|\/set|\/include)}}/) {
                            else_content = else_content (else_content != "" ? "\n" : "") remaining
                        }
                    } else {
                        add_content(remaining)
                        content = stack[stack_size, "content"]
                    }
                }
                
                gsub(/\n/, "\001", content)
                if (type == "if" && in_else) {
                    else_end_line = line_num
                    gsub(/\n/, "\001", else_content)
                    print type "|" start "|" line_num "|" condition "|" content
                    print "else|" else_start "|" else_end_line "||" else_content
                } else {
                    print type "|" start "|" line_num "|" condition "|" content
                }
                
                pop_construct()
                return 1
            } else {
                stack[stack_size, "brace_count"] = brace_count
                add_content(line)
                return 1
            }
        } else {
            add_content(line)
            return 1
        }
    }
    return 0
}

