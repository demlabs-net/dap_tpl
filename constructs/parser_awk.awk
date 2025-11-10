# Parser for awk constructs: {{#awk:...}} or {{#awk:...}}...{{}}
# Uses stack_manager.awk functions

@include "stack_manager.awk"
@include "marker_detector.awk"

# Process awk construct marker
function process_awk_marker(line, line_num,    condition, remaining, result) {
    result = extract_awk_condition(line)
    if (result != "") {
        split(result, parts, "|")
        condition = parts[1]
        remaining = parts[2]
        if (remaining != "") {
            # AWK script is complete on one line - output immediately
            print "awk|" line_num "|" line_num "|" condition "|" remaining
            return 2  # Return 2 to indicate immediate output
        } else {
            # Multi-line AWK
            push_construct("awk", condition, line_num, 2)
            return 1
        }
    }
    return 0
}

# Process awk closing marker }}
function process_awk_closing(line_num,    type, condition, start, content) {
    if (stack_size > 0 && stack[stack_size, "type"] == "awk") {
        type = stack[stack_size, "type"]
        condition = stack[stack_size, "condition"]
        start = stack[stack_size, "start_line"]
        content = stack[stack_size, "content"]
        gsub(/\n/, "\001", content)
        print type "|" start "|" line_num "|" condition "|" content
        pop_construct()
        return 1
    }
    return 0
}

