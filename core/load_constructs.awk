# Load constructs from constructs_file and processed content from processed_file
# Populates arrays: constructs[], construct_end[], construct_types[], processed_lines[]

function load_constructs(constructs_file, processed_file,    line, parts, construct_type, start_line, end_line, processed_content, i, processed_count) {
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
    
    return processed_count
}

