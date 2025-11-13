# COMMENT Construct Content Parser
# Handles special content parsing for comment constructs

@include "core/token_tree.awk"

# Find matching closing }} for marker starting at pos (local helper)
# This is a local copy to avoid dependency on tokenizer_core
function find_comment_marker_close(content, pos,    depth, i, marker_end) {
    if (substr(content, pos, 2) != "{{") {
        return 0
    }
    
    depth = 0
    marker_end = 0
    for (i = pos + 2; i <= length(content) - 1; i++) {
        if (substr(content, i, 2) == "{{") {
            depth++
            i++
        } else if (substr(content, i, 2) == "}}") {
            if (depth == 0) {
                marker_end = i - pos - 1
                break
            }
            depth--
            i++
        }
    }
    
    if (marker_end > 0) {
        return marker_end
    }
    
    return 0
}

# Parse single-line comment content
# Parameters:
#   content - full content
#   start_pos - position after opening marker
#   token_id - comment token ID
# Returns: position after comment (end of marker)
function parse_comment_content(content, start_pos, token_id,    marker_end, marker_pos) {
    # Single-line comments are self-contained - content is already in token
    # Find closing }} and return position after it
    marker_end = find_comment_marker_close(content, start_pos - 2)
    if (marker_end > 0) {
        marker_pos = start_pos - 2 + marker_end
        # Return position after }}
        return marker_pos + 2
    }
    return start_pos
}

# Parse multi-line comment content
# Parameters:
#   content - full content
#   start_pos - position after opening marker {{!--
#   token_id - comment token ID
# Returns: position after --}}
function parse_comment_ml_content(content, start_pos, token_id,    pos, marker_pos, marker_end, marker_text, actual_pos, comment_content, closing_pos) {
    # Find closing --}}
    pos = start_pos
    
    while (pos <= length(content)) {
        marker_pos = match(substr(content, pos), /{{/)
        if (marker_pos == 0) {
            break
        }
        
        actual_pos = pos + marker_pos - 1
        marker_end = find_comment_marker_close(content, actual_pos)
        if (marker_end == 0) {
            pos = actual_pos + 2
            continue
        }
        
        marker_text = substr(content, actual_pos + 2, marker_end - 1)
        
        # Check for -- closing marker
        if (marker_text == "--") {
            # Extract comment content (between {{!-- and --}})
            comment_content = substr(content, start_pos, actual_pos - start_pos)
            # Store in token value
            set_token_value(token_id, comment_content)
            # Move past --}}
            closing_pos = match(substr(content, actual_pos), /}}/)
            if (closing_pos > 0) {
                return actual_pos + closing_pos + 1
            }
            return actual_pos + 1
        }
        
        pos = actual_pos + 2 + marker_end + 1
    }
    
    # No closing found - treat as self-contained
    return start_pos
}

