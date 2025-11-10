# Parser for set constructs: {{#set VAR=value}}...{{/set}}
# Uses stack_manager.awk functions

@include "stack_manager.awk"
@include "marker_detector.awk"

# Process set construct marker
function process_set_marker(line, line_num,    condition, remaining, result) {
    result = extract_set_condition(line)
    if (result != "") {
        split(result, parts, "|")
        condition = parts[1]
        remaining = parts[2]
        push_construct("set", condition, line_num, 2)
        if (remaining != "") {
            add_content(remaining)
        }
        return 1
    }
    return 0
}

