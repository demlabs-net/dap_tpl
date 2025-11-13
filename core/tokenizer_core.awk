# Tokenizer Core - Data-Driven Tokenizer
# Uses registry to parse constructs instead of hardcoded checks
# This is the universal tokenizer that dispatches to construct-specific tokenizers

@include "core/token_tree.awk"
@include "core/construct_registry.awk"

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
                    delete text_metadata
                    text_metadata["skip_empty_text"] = "1"
                    text_token_id = create_token("text", remaining, text_metadata)
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
                delete text_metadata
                text_metadata["skip_empty_text"] = "1"
                text_token_id = create_token("text", text_before, text_metadata)
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
        marker_text = substr(content, actual_pos + 2, marker_end - 1)
        
        # Check for closing tags first (using registry)
        closing_construct = get_construct_for_closing(marker_text)
        if (closing_construct != "") {
            # Closing tag - stop parsing and return
            return actual_pos - 1
        }
        
        # Check if this is a branch marker for any registered construct
        # This is done generically using registry - no hardcoded checks
        branch_marker_found = 0
        for (check_type in CONSTRUCT_PATTERNS) {
            if (is_branch_marker(check_type, marker_text)) {
                branch_marker_found = 1
                break
            }
        }
        if (branch_marker_found) {
            # Branch marker - stop parsing and return position
            return actual_pos - 1
        }
        
        # Parse opening construct using registry
        token_id = parse_construct_marker(marker_text, actual_pos, start_line)
        if (token_id > 0) {
            # Construct found
            construct_type = get_token_type(token_id)
            
            # Check if it's a self-contained construct (using registry)
            if (is_self_contained(construct_type)) {
                # Check if it has a content parser for special handling
                content_parser_func = get_content_parser(construct_type)
                if (content_parser_func != "") {
                    # Use construct-specific content parser via dispatch
                    content_start_pos = actual_pos + 2 + marker_end + 1
                    pos = dispatch_content_parser(construct_type, content, content_start_pos, token_id)
                    add_child(parent_id, token_id)
                    continue
                } else {
                    # Self-contained without special parser - just add and skip
                    add_child(parent_id, token_id)
                    pos = actual_pos + 2 + marker_end + 1
                    continue
                }
            }
            
            # Find its content and closing tag
            content_start_pos = actual_pos + 2 + marker_end + 1
            result = find_construct_content(content, content_start_pos, marker_text, token_id, construct_type, start_line)
            construct_end = result
            
            if (construct_end > 0) {
                # Extract inner content (between opening and closing tags)
                inner_content = substr(content, content_start_pos, construct_end - content_start_pos)
                
                # Check if this construct has a branch parser registered
                branch_parser_func = get_branch_parser(construct_type)
                if (branch_parser_func != "") {
                    # Use construct-specific branch parser via dispatch
                    dispatch_branch_parser(construct_type, inner_content, token_id, start_line)
                } else {
                    # No branch parser - parse normally
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
                # No closing tag found - treat as self-contained
                add_child(parent_id, token_id)
                pos = actual_pos + 2 + marker_end + 1
            }
        } else {
            # Variable or other marker
            token_id = parse_variable_marker(marker_text, actual_pos, start_line)
            if (token_id > 0) {
                add_child(parent_id, token_id)
            }
            pos = actual_pos + 2 + marker_end + 1
        }
    }
    
    return 0
}

# Parse construct opening marker using registry
# Parameters:
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
# Returns: token ID or 0
function parse_construct_marker(marker_text, pos, start_line,    construct_type, pattern, func_name, token_id) {
    # Iterate through registered patterns
    for (construct_type in CONSTRUCT_PATTERNS) {
        pattern = CONSTRUCT_PATTERNS[construct_type]
        if (match(marker_text, pattern)) {
            # Get registered tokenizer function
            func_name = TOKENIZER_FUNCTIONS[construct_type]
            
            # Call it via dispatch (will be generated by build_engine.sh)
            # build_engine.sh defines dispatch_tokenizer before this code runs
            token_id = dispatch_tokenizer(func_name, marker_text, pos, start_line, construct_type)
            if (token_id > 0) {
                return token_id
            }
        }
    }
    return 0
}

# Dispatch to actual tokenizer function (compile-time generated)
# This function is defined by build_engine.sh before core files are included
# Parameters:
#   func_name - name of tokenizer function
#   marker_text - marker text
#   pos - position
#   start_line - starting line number
#   construct_type - construct type
# Returns: token ID or 0
# NOTE: This function must be defined by build_engine.sh before @include of this file

# Find content and end position of construct
# Parameters:
#   content - text content
#   start_pos - absolute position to start searching (after opening tag)
#   opening_marker - opening marker text (e.g., "#if VAR")
#   token_id - token ID of the construct
#   construct_type - construct type
#   start_line - starting line number
# Returns: absolute position of closing tag or 0
function find_construct_content(content, start_pos, opening_marker, token_id, construct_type, start_line,    pos, marker_pos, marker_end, marker_text, depth, closing_tag, actual_marker_pos) {
    # Get closing tag from registry
    closing_tag = ""
    for (tag in CLOSING_PATTERNS) {
        if (CLOSING_PATTERNS[tag] == construct_type) {
            closing_tag = tag
            break
        }
    }
    
    if (closing_tag == "") {
        # No closing tag registered - treat as self-contained
        return 0
    }
    
    # Remove ^ and $ from pattern for matching
    closing_pattern = closing_tag
    gsub(/^\^|\$$/, "", closing_pattern)
    
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
        
        # Check for matching opening tag (same construct type)
        for (pattern_type in CONSTRUCT_PATTERNS) {
            if (pattern_type == construct_type) {
                pattern = CONSTRUCT_PATTERNS[pattern_type]
                if (match(marker_text, pattern)) {
                    depth++
                    break
                }
            }
        }
        
        # Check for matching closing tag
        if (match(marker_text, closing_pattern)) {
            depth--
            if (depth == 0) {
                # Return absolute position of closing tag
                return actual_marker_pos
            }
        }
        # Check for branch markers (elif/else) at top level (depth 1)
        # This is done generically using registry
        else if (depth == 1) {
            if (is_branch_marker(construct_type, marker_text)) {
                # Found branch marker at top level - this is valid, continue searching
                # The branch parser will handle it
            }
        }
        
        # Move to position after closing }}
        pos = actual_marker_pos + 2 + marker_end + 1
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

