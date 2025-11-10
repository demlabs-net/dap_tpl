# Replace template constructs in template file
# Reads constructs file and processed content, replaces markers in template

BEGIN {
    # Read constructs mapping (start_line -> processed_content)
    while ((getline line < constructs_file) > 0) {
        split(line, parts, "|")
        if (length(parts) >= 5) {
            construct_type = parts[1]
            start_line = parts[2]
            end_line = parts[3]
            processed_content = parts[5]
            # Handle multi-line content
            if (length(parts) > 5) {
                for (i = 6; i <= length(parts); i++) {
                    processed_content = processed_content "|" parts[i]
                }
            }
            constructs[start_line] = processed_content
            construct_end[start_line] = end_line
            construct_types[start_line] = construct_type
        }
    }
    close(constructs_file)
    
    # Read processed content
    processed_count = 0
    while ((getline line < processed_file) > 0) {
        processed_count++
        processed_lines[processed_count] = line
    }
    close(processed_file)
    
    # Track which constructs we've output
    processed_idx = 1
    skip_until = 0
}

{
    current_line = NR
    
    # Reset skip_until if we've passed it
    if (current_line > skip_until) {
        skip_until = 0
    }
    
    # Check if we're in a construct that should be replaced
    replaced = 0
    for (start in constructs) {
        if (current_line >= start && current_line <= construct_end[start]) {
            # This line is part of a construct
            construct_type = construct_types[start]
            if (current_line == start) {
                # For "var" constructs, ignore them - they should be processed as regular variables
                # Simple variables like {{BASENAME}} should NOT create construct entries
                # They are processed directly in the variable replacement phase below
                if (construct_type == "var") {
                    # Skip this construct - let it be processed as a regular variable
                    # But we need to skip the processed content from processed_file
                    if (processed_idx <= processed_count) {
                        processed_idx++  # Skip the processed content
                    }
                    skip_until = construct_end[start]
                    replaced = 0  # Don't mark as replaced - let it fall through to variable replacement
                    break
                } else {
                    # For other construct types, output processed content instead
                    if (processed_idx <= processed_count) {
                        print processed_lines[processed_idx]
                        processed_idx++
                    }
                    skip_until = construct_end[start]
                    replaced = 1
                    break
                }
            } else if (current_line <= skip_until && construct_type != "var") {
                # Skip original construct lines (but not var constructs - they're processed as variables)
                replaced = 1
                break
            }
        }
    }
    
    if (!replaced) {
        # Output line as-is WITHOUT replacing {{VAR}} markers
        # Placeholder replacement happens later in replace_template_value.awk
        # This prevents double replacement and ensures correct order
        print $0
    }
}

