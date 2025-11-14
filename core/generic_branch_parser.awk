# Generic Branch Parser
# Universal branch parser for constructs with elif/else-like branches
# Uses registry to determine branch marker patterns and token types
# Note: DEBUG_FILE_NAME is automatically set by build_engine.sh

@include "core/token_tree.awk"
@include "core/construct_registry.awk"
@include "core/tokenizer_core.awk"
@include "core/marker_utils.awk"
@include "core/debug.awk"

# Find positions of branch markers in content using registry
# Parameters:
#   content - content to search
#   construct_type - construct type (e.g., "if", "c_ifdef")
#   positions - output array: positions[i, "pos"], positions[i, "type"], positions[i, "condition"]
# Returns: count of branches found
function find_branches_generic(content, construct_type, positions,    pos, marker_pos, marker_end, marker_text, count, actual_pos, pattern, token_type, condition_match) {
    delete positions
    count = 0
    pos = 1
    
    while (pos <= length(content)) {
        marker_pos = match(substr(content, pos), /{{/)
        if (marker_pos == 0) {
            break
        }
        
        actual_pos = pos + marker_pos - 1
        marker_end = find_matching_close(content, actual_pos)
        if (marker_end == 0) {
            pos = actual_pos + 2
            continue
        }
        
        marker_text = substr(content, actual_pos + 2, marker_end - 1)
        
        # Check if this is a branch marker for the construct using registry
        if (is_branch_marker(construct_type, marker_text)) {
            # Get token type from registry
            token_type = get_special_marker_type(construct_type, marker_text)
            if (token_type != "") {
                count++
                positions[count, "pos"] = actual_pos
                positions[count, "type"] = token_type
                
                # Extract condition from marker_text
                # For patterns with capture groups like "^#elif[ \t]+(.+)$", extract condition
                # For patterns without capture groups like "^else$", condition is empty
                condition_match = ""
                if (construct_type in SPECIAL_MARKERS) {
                    for (pattern in SPECIAL_MARKERS[construct_type]) {
                        if (match(marker_text, pattern)) {
                            # Pattern matched - check if it has capture group for condition
                            if (pattern ~ /\(\.\+\)/) {
                                # Pattern has capture group - extract condition
                                # Find keyword end position in marker_text
                                keyword_end = 0
                                if (match(marker_text, /^#?[a-z_]+/)) {
                                    keyword_end = RSTART + RLENGTH
                                    # Skip whitespace
                                    while (keyword_end <= length(marker_text) && substr(marker_text, keyword_end, 1) ~ /[ \t]/) {
                                        keyword_end++
                                    }
                                    if (keyword_end <= length(marker_text)) {
                                        condition_match = substr(marker_text, keyword_end)
                                        gsub(/^[ \t]+|[ \t]+$/, "", condition_match)
                                    }
                                }
                            }
                            break
                        }
                    }
                }
                
                positions[count, "condition"] = condition_match
            }
        }
        
        pos = skip_to_after_marker(actual_pos, marker_end)
    }
    
    positions["count"] = count
    return count
}

# Parse branches generically using registry
# Parameters:
#   content - content to parse
#   token_id - parent token ID
#   construct_type - construct type
#   start_line - starting line number
function parse_branches_generic(content, token_id, construct_type, start_line,    positions, count, i, current_pos, next_pos, branch_content, branch_token_id, metadata, marker_end) {
    delete positions
    count = find_branches_generic(content, construct_type, positions)
    
    # Debug output
    if (construct_type == "if" && content ~ /type.*==.*void/) {
        log_debug("parse_branches_generic: token_id=%d construct_type=%s count=%d content_length=%d", token_id, construct_type, count, length(content))
    }
    
    if (count == 0) {
        # No branches - parse normally
        parse_content(content, token_id, start_line)
        
        # Debug output
        if (construct_type == "if" && content ~ /type.*==.*void/) {
            log_debug("after parse_content, token_id=%d children=%d", token_id, get_children_count(token_id))
        }
        return
    }
    
    current_pos = 1
    
    # Parse main branch (before first branch marker)
    next_pos = positions[1, "pos"]
    branch_content = substr(content, current_pos, next_pos - current_pos)
    
    # Debug output
    if (construct_type == "if" && content ~ /type.*==.*void/) {
        log_debug("parsing main branch, content=[%s]", branch_content)
    }
    
    parse_content(branch_content, token_id, start_line)
    
    # Debug output
    if (construct_type == "if" && content ~ /type.*==.*void/) {
        log_debug("after main branch, token_id=%d children=%d", token_id, get_children_count(token_id))
    }
    
    current_pos = next_pos
    
    # Parse branch markers
    for (i = 1; i <= count; i++) {
        # Skip marker
        marker_end = find_matching_close(content, positions[i, "pos"])
        current_pos = skip_to_after_marker(positions[i, "pos"], marker_end)
        
        # Determine end of this branch
        if (i < count) {
            next_pos = positions[i + 1, "pos"]
        } else {
            next_pos = length(content) + 1
        }
        
        branch_content = substr(content, current_pos, next_pos - current_pos)
        
        # Create branch token using type from registry
        delete metadata
        if (positions[i, "condition"] != "") {
            metadata["condition"] = positions[i, "condition"]
        }
        branch_token_id = create_token(positions[i, "type"], "", metadata)
        
        parse_content(branch_content, branch_token_id, start_line)
        add_child(token_id, branch_token_id)
        
        # Debug output
        if (construct_type == "if" && content ~ /type.*==.*void/) {
            log_debug("added branch %s, branch_children=%d total_children=%d", positions[i, "type"], get_children_count(branch_token_id), get_children_count(token_id))
        }
    }
    
    # Store metadata indicating branches were found
    set_token_metadata(token_id, "has_branches", "1")
    
    # Debug output
    if (construct_type == "if" && content ~ /type.*==.*void/) {
        log_debug("final token_id=%d children=%d", token_id, get_children_count(token_id))
    }
}

