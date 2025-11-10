# Parser for for constructs: {{#for item in ARRAY}}...{{/for}}
# Uses stack_manager.awk functions

@include "stack_manager.awk"
@include "marker_detector.awk"

# Process for construct marker
function process_for_marker(line, line_num,    condition, remaining, result) {
    result = extract_for_condition(line)
    if (result != "") {
        split(result, parts, "|")
        condition = parts[1]
        remaining = parts[2]
        push_construct("for", condition, line_num, 2)
        if (remaining != "") {
            add_content(remaining)
        }
        return 1
    }
    return 0
}

