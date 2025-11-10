# Tokenizer - Recursive Descent Parser
# Parses template text into AST (Abstract Syntax Tree) of tokens
# No escape logic - works with clean data structures

@include "core/token_tree.awk"

BEGIN {
    # Root token for the entire template
    root_token_id = 0
    current_line_num = 0
}

# Main tokenization function
# Parameters:
#   template_text - full template text as string
# Returns: root token ID
function tokenize(template_text,    root_id) {
    # Create root token
    root_id = create_token("root", "", "")
    root_token_id = root_id
    
    # Parse template recursively
    current_line_num = 1
    parse_content(template_text, root_id, 1)
    
    return root_id
}

# Parse content recursively, handling nested constructs
# Parameters:
#   content - text content to parse
#   parent_id - parent token ID
#   start_line - starting line number (for tracking)
# Returns: number of characters consumed, or -1 if closing tag found
function parse_content(content, parent_id, start_line,    pos, text_start, marker_pos, marker_end, marker_text, token_id, construct_end, inner_content, else_pos, else_content, result, consumed) {
    pos = 1
    
    while (pos <= length(content)) {
        # Find next marker {{...}}
        marker_pos = match(substr(content, pos), /{{/)
        if (marker_pos == 0) {
            # No more markers - add remaining text
            if (pos <= length(content)) {
                remaining = substr(content, pos)
                if (remaining != "") {
                    text_token_id = create_token("text", remaining, "")
                    add_child(parent_id, text_token_id)
                }
            }
            break
        }
        
        actual_pos = pos + marker_pos - 1
        
        # Add text before marker
        if (marker_pos > 1) {
            text_before = substr(content, actual_pos - marker_pos + 1, marker_pos - 1)
            if (text_before != "") {
                text_token_id = create_token("text", text_before, "")
                add_child(parent_id, text_token_id)
            }
        }
        
        # Parse marker
        marker_end = find_matching_close(content, actual_pos)
        if (marker_end == 0) {
            # Malformed marker - skip it
            pos = actual_pos + 2
            continue
        }
        
        # Extract marker content (between {{ and }})
        # marker_end is position of }} relative to actual_pos + 2
        marker_text = substr(content, actual_pos + 2, marker_end - 1)
        
        # Check for closing tags first
        if (marker_text == "/if" || marker_text == "/for" || marker_text == "/set") {
            # Closing tag - stop parsing and return
            return actual_pos - 1
        }
        
        # Check for else branch
        if (marker_text == "else") {
            # {{else}} - stop parsing and return position
            return actual_pos - 1
        }
        
        # Parse opening construct
        token_id = parse_construct_marker(marker_text, actual_pos, start_line)
        if (token_id > 0) {
            # Construct found - find its content and closing tag
            # marker_end is relative to actual_pos+2, so absolute position after }} is actual_pos + 2 + marker_end + 1
            content_start_pos = actual_pos + 2 + marker_end + 1
            result = find_construct_content(content, content_start_pos, marker_text, token_id, start_line)
            construct_end = result
            
            if (construct_end > 0) {
                # Extract inner content (between opening and closing tags)
                # construct_end is absolute position of closing tag
                inner_content = substr(content, content_start_pos, construct_end - content_start_pos)
                
                # Check for else branch in if constructs
                else_pos = match(inner_content, /{{else}}/)
                if (else_pos > 0 && get_token_type(token_id) == "if") {
                    # Split into if and else content
                    else_content = substr(inner_content, else_pos + 7)
                    inner_content = substr(inner_content, 1, else_pos - 1)
                    
                    # Parse if content
                    parse_content(inner_content, token_id, start_line)
                    
                    # Create else token and parse else content
                    else_token_id = create_token("else", "", "")
                    parse_content(else_content, else_token_id, start_line)
                    add_child(token_id, else_token_id)
                    
                    # Store else content metadata
                    set_token_metadata(token_id, "has_else", "1")
                } else {
                    # Parse inner content recursively
                    parse_content(inner_content, token_id, start_line)
                }
                
                # Add construct to parent
                add_child(parent_id, token_id)
                
                # Find position after closing tag
                closing_marker_pos = match(substr(content, construct_end), /}}/)
                if (closing_marker_pos > 0) {
                    pos = construct_end + closing_marker_pos + 1
                } else {
                    pos = construct_end + 1
                }
            } else {
                # No closing tag found - treat as self-contained (for single-line constructs)
                add_child(parent_id, token_id)
                # marker_end is relative, absolute position after }} is actual_pos + 2 + marker_end + 1
                pos = actual_pos + 2 + marker_end + 1
            }
        } else {
            # Variable or other marker
            token_id = parse_variable_marker(marker_text, actual_pos, start_line)
            if (token_id > 0) {
                add_child(parent_id, token_id)
            }
            # marker_end is relative, absolute position after }} is actual_pos + 2 + marker_end + 1
            pos = actual_pos + 2 + marker_end + 1
        }
    }
    
    return 0
}

# Find content and end position of construct
# Parameters:
#   content - text content
#   start_pos - absolute position to start searching (after opening tag)
#   opening_marker - opening marker text (e.g., "#if VAR")
#   token_id - token ID of the construct
#   start_line - starting line number
# Returns: absolute position of closing tag or 0
function find_construct_content(content, start_pos, opening_marker, token_id, start_line,    pos, marker_pos, marker_end, marker_text, depth, construct_type, closing_tag, actual_marker_pos) {
    # Determine construct type and closing tag
    if (match(opening_marker, /^#if/)) {
        construct_type = "if"
        closing_tag = "/if"
    } else if (match(opening_marker, /^#for/)) {
        construct_type = "for"
        closing_tag = "/for"
    } else if (match(opening_marker, /^#set/)) {
        construct_type = "set"
        closing_tag = "/set"
    } else {
        return 0
    }
    
    depth = 1
    pos = start_pos
    
    while (pos <= length(content)) {
        marker_pos = match(substr(content, pos), /{{/)
        if (marker_pos == 0) {
            break
        }
        
        actual_marker_pos = pos + marker_pos - 1
        marker_end = find_matching_close(content, actual_marker_pos)
        if (marker_end == 0) {
            pos = actual_marker_pos + 2
            continue
        }
        
        marker_text = substr(content, actual_marker_pos + 2, marker_end - 1)
        
        # Check for matching opening tag
        if (match(marker_text, "^#" construct_type)) {
            depth++
        }
        # Check for matching closing tag
        else if (marker_text == closing_tag) {
            depth--
            if (depth == 0) {
                # Return absolute position of closing tag
                return actual_marker_pos
            }
        }
        # Check for else (only for if constructs, and only at depth 1)
        else if (marker_text == "else" && construct_type == "if" && depth == 1) {
            # Found else at top level - this is valid, continue searching
        }
        
        # Move to position after closing }}
        # marker_end is relative to actual_marker_pos+2, so absolute position after }} is actual_marker_pos + 2 + marker_end + 1
        pos = actual_marker_pos + 2 + marker_end + 1
    }
    
    return 0
}

# Parse construct opening marker
# Parameters:
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
# Returns: token ID or 0
function parse_construct_marker(marker_text, pos, start_line,    condition, metadata, token_id, var_name, match_result) {
    if (match(marker_text, /^#if[ \t]+(.+)$/)) {
        # {{#if VAR}}
        condition = substr(marker_text, RSTART + 4)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        
        delete metadata
        metadata["condition"] = condition
        metadata["start_line"] = start_line
        
        return create_token("if", "", metadata)
    }
    else if (match(marker_text, /^#for[ \t]+(.+)$/)) {
        # {{#for item in ARRAY}}
        condition = substr(marker_text, RSTART + 5)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        
        delete metadata
        metadata["condition"] = condition
        metadata["start_line"] = start_line
        
        return create_token("for", "", metadata)
    }
    else if (match(marker_text, /^#set[ \t]+(.+)$/)) {
        # {{#set VAR=value}}
        condition = substr(marker_text, RSTART + 5)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        
        delete metadata
        metadata["condition"] = condition
        metadata["start_line"] = start_line
        
        return create_token("set", "", metadata)
    }
    else if (match(marker_text, /^AWK:(.+)$/)) {
        # {{AWK:...}}
        var_name = substr(marker_text, RSTART + 4)
        
        delete metadata
        metadata["start_line"] = start_line
        
        return create_token("awk_section", var_name, metadata)
    }
    
    return 0
}

# Parse variable marker
# Parameters:
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
# Returns: token ID or 0
function parse_variable_marker(marker_text, pos, start_line,    metadata, token_id) {
    # {{VAR}} or {{VAR|function|args}}
    # Check if it's NOT a construct marker (doesn't start with # or /)
    if (substr(marker_text, 1, 1) != "#" && substr(marker_text, 1, 1) != "/") {
        delete metadata
        metadata["var_name"] = marker_text
        metadata["start_line"] = start_line
        
        return create_token("var", "", metadata)
    }
    
    return 0
}

# Find matching closing }} for marker starting at pos
# Parameters:
#   content - text content
#   pos - position of {{ marker
# Returns: position of }} (first character) relative to pos+2, or 0 if not found
function find_matching_close(content, pos,    depth, i, marker_end) {
    if (substr(content, pos, 2) != "{{") {
        return 0
    }
    
    # Find matching closing }} accounting for nested markers
    depth = 0
    marker_end = 0
    for (i = pos + 2; i <= length(content) - 1; i++) {
        if (substr(content, i, 2) == "{{") {
            depth++
            i++  # Skip second {
        } else if (substr(content, i, 2) == "}}") {
            if (depth == 0) {
                # i is position of first } in }}
                # Position relative to pos+2: (i - (pos + 2)) + 1 = i - pos - 1
                marker_end = i - pos - 1
                break
            }
            depth--
            i++  # Skip second }
        }
    }
    
    if (marker_end > 0) {
        return marker_end  # Return position relative to pos+2
    }
    
    return 0
}

# Tokenize from file (for compatibility)
# Reads template from file and returns root token ID
function tokenize_file(filename,    content, line, token_id) {
    content = ""
    while ((getline line < filename) > 0) {
        if (content != "") {
            content = content "\n"
        }
        content = content line
    }
    close(filename)
    
    return tokenize(content)
}

# Get root token ID
function get_root_token() {
    return root_token_id
}
