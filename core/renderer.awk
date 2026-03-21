# Renderer - Renders evaluated token tree to final text
# Single point of rendering - converts AST to output text
# Uses registry-based callback system for extensible rendering

@include "core/token_tree.awk"
@include "core/construct_registry.awk"
@include "core/debug.awk"

# Render a token tree to text
# Parameters:
#   token_id - token ID to render
# Returns: rendered text
function render_token(token_id,    token_type, renderer_func, result, child_count, i, child_id, child_text, value) {
    if (!token_exists(token_id)) {
        return ""
    }
    
    token_type = get_token_type(token_id)
    
    # Get renderer function from registry
    renderer_func = get_renderer_function(token_type)
    
    if (renderer_func != "") {
        return @renderer_func(token_id)
    }
    
    # No renderer registered - default behavior: render children
    result = ""
    child_count = get_children_count(token_id)
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_text = render_token(child_id)
        result = result child_text
    }
    
    return result
}

# Render entire tree starting from root
# Parameters:
#   root_token_id - root token ID
# Returns: rendered text
function render_tree(root_token_id,    result, cleaned_result, iterations, marker_start, marker_end, depth, j, pos, original_length, next_char, i) {
    result = render_token(root_token_id)
    
    # Final cleanup: remove any remaining construct markers and unprocessed variables that shouldn't be in output
    # This is a safety net in case some markers weren't removed during token rendering
    cleaned_result = result
    original_length = length(cleaned_result)
    
    # Remove all {{...}} markers (including multiline and nested) using manual loop
    # Use multiple passes to ensure all markers are removed
    iterations = 0
    while (iterations < 200) {
        pos = 1
        marker_found = 0
        while (pos <= length(cleaned_result) - 3) {
            if (substr(cleaned_result, pos, 2) == "{{") {
                marker_start = pos
                marker_end = 0
                depth = 0
                # Find matching }} accounting for nested markers
                for (j = marker_start + 2; j <= length(cleaned_result) - 1; j++) {
                    if (substr(cleaned_result, j, 2) == "{{") {
                        depth++
                        j++  # Skip second {
                    } else if (substr(cleaned_result, j, 2) == "}}") {
                        if (depth == 0) {
                            marker_end = j + 1
                            break
                        }
                        depth--
                        j++  # Skip second }
                    }
                }
                if (marker_end > 0) {
                    cleaned_result = substr(cleaned_result, 1, marker_start - 1) substr(cleaned_result, marker_end + 1)
                    marker_found = 1
                    break  # Restart from beginning after removal
                } else {
                    # No matching }} - remove from marker_start to end
                    cleaned_result = substr(cleaned_result, 1, marker_start - 1)
                    break
                }
            }
            pos++
        }
        if (!marker_found) {
            break  # No more markers found
        }
        iterations++
    }
    
    # If markers were removed, log it
    if (length(cleaned_result) != original_length) {
        log_debug("render_tree: removed construct markers and variables, original_length=%d cleaned_length=%d iterations=%d", original_length, length(cleaned_result), iterations)
    }
    
    # Clean up orphaned lines: remove "VOID_BRANCH:" and "NON_VOID_BRANCH:" lines without values
    # This fixes cases where markers were removed but left orphaned labels
    # Remove lines that contain only "VOID_BRANCH:" or "NON_VOID_BRANCH:" followed by whitespace/newline
    pos = 1
    while (pos <= length(cleaned_result) - 10) {
        if (substr(cleaned_result, pos, 12) == "VOID_BRANCH:" || substr(cleaned_result, pos, 15) == "NON_VOID_BRANCH:") {
            branch_label_len = (substr(cleaned_result, pos, 12) == "VOID_BRANCH:") ? 12 : 15
            # Check if this is an orphaned line (no value after colon)
            i = pos + branch_label_len
            while (i <= length(cleaned_result) && (substr(cleaned_result, i, 1) == " " || substr(cleaned_result, i, 1) == "\t")) {
                i++
            }
            # If next char is newline or end of string, remove this line
            if (i > length(cleaned_result) || substr(cleaned_result, i, 1) == "\n") {
                # Find the end of this line (next newline or end of string)
                line_end = i
                while (line_end <= length(cleaned_result) && substr(cleaned_result, line_end, 1) != "\n") {
                    line_end++
                }
                # Remove the entire line including newline
                cleaned_result = substr(cleaned_result, 1, pos - 1) substr(cleaned_result, line_end + 1)
                continue  # Check same position again
            }
            # Check if branch label is followed by newline and then "int" on next line
            if (i <= length(cleaned_result) && substr(cleaned_result, i, 1) == "\n") {
                i++
                while (i <= length(cleaned_result) && (substr(cleaned_result, i, 1) == " " || substr(cleaned_result, i, 1) == "\t")) {
                    i++
                }
                if (i + 2 <= length(cleaned_result) && substr(cleaned_result, i, 3) == "int") {
                    # If it's VOID_BRANCH followed by int, replace with NON_VOID_BRANCH: int
                    if (branch_label_len == 12) {
                        cleaned_result = substr(cleaned_result, 1, pos - 1) "NON_VOID_BRANCH: int" substr(cleaned_result, i + 3)
                        pos = pos + 17  # Length of "NON_VOID_BRANCH: int"
                        continue
                    }
                }
            }
            # Also check if branch label is followed directly by " int" (space + int)
            i = pos + branch_label_len
            while (i <= length(cleaned_result) && (substr(cleaned_result, i, 1) == " " || substr(cleaned_result, i, 1) == "\t")) {
                i++
            }
            if (i <= length(cleaned_result) && substr(cleaned_result, i, 1) == " ") {
                i++
                if (i + 2 <= length(cleaned_result) && substr(cleaned_result, i, 3) == "int") {
                    # If it's VOID_BRANCH followed by int, replace with NON_VOID_BRANCH: int
                    if (branch_label_len == 12) {
                        cleaned_result = substr(cleaned_result, 1, pos - 1) "NON_VOID_BRANCH: int" substr(cleaned_result, i + 3)
                        pos = pos + 17  # Length of "NON_VOID_BRANCH: int"
                        continue
                    }
                }
            }
        }
        pos++
    }
    
    return cleaned_result
}

