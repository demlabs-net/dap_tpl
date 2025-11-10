# Replace constructs in template file
# Uses load_constructs.awk arrays: constructs[], construct_end[], construct_types[], processed_lines[]

@include "core/load_constructs.awk"

# Check if current line is part of a construct that should be replaced
function should_replace_construct(current_line, skip_until,    start, construct_type, replaced) {
    replaced = 0
    for (start in constructs) {
        if (current_line >= start && current_line <= construct_end[start]) {
            construct_type = construct_types[start]
            if (current_line == start) {
                # For "var" constructs, ignore them - they should be processed as regular variables
                if (construct_type == "var") {
                    skip_until = construct_end[start]
                    return 0  # Don't replace, let it be processed as variable
                } else {
                    skip_until = construct_end[start]
                    return 1  # Replace with processed content
                }
            } else if (current_line <= skip_until && construct_type != "var") {
                # Skip original construct lines (but not var constructs)
                return 1  # Skip this line
            }
        }
    }
    return 0  # Don't replace
}

# Get processed content for construct at start_line
function get_processed_content(start_line, processed_idx, processed_count,    result) {
    if (processed_idx <= processed_count) {
        result = processed_lines[processed_idx]
        processed_idx++
        return result "|" processed_idx  # Return content and new index
    }
    return "|" processed_idx
}

