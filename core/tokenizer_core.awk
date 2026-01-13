# Tokenizer Core - Data-Driven Tokenizer
# Uses registry to parse constructs instead of hardcoded checks
# This is the universal tokenizer that dispatches to construct-specific tokenizers

@include "core/token_tree.awk"
@include "core/construct_registry.awk"
@include "core/debug.awk"

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
    root_id = create_token("root", "")
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
function parse_content(content, parent_id, start_line,    pos, text_start, marker_pos, marker_end, marker_text, token_id, construct_end, inner_content, else_pos, else_content, result, consumed, parent_type, parent_condition) {
    # Debug output for set tokens
    parent_type = get_token_type(parent_id)
    if (parent_type == "set") {
        log_debug("parse_content: START for set, parent_id=%d content_length=%d content=[%s]", parent_id, length(content), substr(content, 1, 200))
    }
    # Debug output for if tokens (parent is if)
    if (parent_type == "if") {
        parent_condition = get_token_metadata(parent_id, "condition")
        if (parent_condition ~ /macro_name/ && content ~ /type.*==.*void/) {
            log_debug("parse_content: START for nested if, parent_id=%d parent_type=%s parent_condition=[%s] content_length=%d", parent_id, parent_type, parent_condition, length(content))
            log_debug("parse_content: START, parent_id=%d parent_type=%s parent_condition=[%s] content_length=%d content=[%s]", parent_id, parent_type, parent_condition, length(content), substr(content, 1, 150))
        }
    }
    
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
            
            # Debug output for ALL if tokens
            if (construct_type == "if") {
                condition = get_token_metadata(token_id, "condition")
                log_debug("parse_content: found if token, token_id=%d condition=[%s] parent_id=%d\n", token_id, condition, parent_id)
            }
            
            # Check if it's a self-contained construct (using registry)
            if (is_self_contained(construct_type)) {
                # Check if it has a content parser for special handling
                content_parser_func = get_content_parser(construct_type)
                if (content_parser_func != "") {
                    # Use construct-specific content parser via dispatch
                    content_start_pos = actual_pos + 2 + marker_end + 1
                    pos = dispatch_3(content_parser_func, content, content_start_pos, token_id)
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
            # Debug output for if tokens with type == 'void' condition
            if (construct_type == "if") {
                condition = get_token_metadata(token_id, "condition")
                if (condition ~ /type.*==.*void/) {
                    log_debug("parse_content: BEFORE find_construct_content, token_id=%d content_start_pos=%d content_length=%d\n", token_id, content_start_pos, length(content))
                    log_debug("parse_content: content from content_start_pos=[%s]\n", substr(content, content_start_pos, 50))
                }
            }
            # Debug output for set tokens
            if (construct_type == "set") {
                log_debug("parse_content: BEFORE find_construct_content for set, token_id=%d actual_pos=%d marker_end=%d content_start_pos=%d content_length=%d\n", token_id, actual_pos, marker_end, content_start_pos, length(content))
                log_debug("parse_content: set, content from actual_pos=[%s]\n", substr(content, actual_pos, 100))
                log_debug("parse_content: set, content from content_start_pos=[%s]\n", substr(content, content_start_pos, 100))
                log_debug("parse_content: set, PARENT_ID=%d PARENT_TYPE=[%s]\n", parent_id, get_token_type(parent_id))
                log_debug("parse_content: set, full content=[%s]\n", content)
            }
            # Debug output for if tokens with type == 'void' condition
            if (construct_type == "if") {
                condition = get_token_metadata(token_id, "condition")
                if (condition ~ /type.*==.*void/) {
                    log_debug("parse_content: BEFORE find_construct_content for nested if, token_id=%d actual_pos=%d marker_end=%d content_start_pos=%d content_length=%d\n", token_id, actual_pos, marker_end, content_start_pos, length(content))
                    log_debug("parse_content: nested if, content from actual_pos=[%s]\n", substr(content, actual_pos, 100))
                    log_debug("parse_content: nested if, content from content_start_pos=[%s]\n", substr(content, content_start_pos, 100))
                }
            }
            result = find_construct_content(content, content_start_pos, marker_text, token_id, construct_type, start_line)
            construct_end = result
            # Debug output for if tokens with type == 'void' condition
            if (construct_type == "if") {
                condition = get_token_metadata(token_id, "condition")
                if (condition ~ /type.*==.*void/) {
                    log_debug("parse_content: find_construct_content returned construct_end=%d for token_id=%d content_start_pos=%d\n", construct_end, token_id, content_start_pos)
                    if (construct_end > 0) {
                        log_debug("parse_content: nested if, content from content_start_pos=[%s]\n", substr(content, content_start_pos, 50))
                        log_debug("parse_content: nested if, content around construct_end=[%s]\n", substr(content, construct_end - 10, 20))
                    }
                }
            }
            
            if (construct_end > 0) {
                # Extract inner content (between opening and closing tags)
                if (construct_type == "set") {
                    log_debug("parse_content: BEFORE substr for set, token_id=%d content_start_pos=%d construct_end=%d content_length=%d\n", token_id, content_start_pos, construct_end, length(content))
                    log_debug("parse_content: set, content around content_start_pos=[%s]\n", substr(content, content_start_pos - 10, 60))
                    log_debug("parse_content: set, content around construct_end=[%s]\n", substr(content, construct_end - 10, 60))
                }
                inner_content = substr(content, content_start_pos, construct_end - content_start_pos)
                
                # Debug output for ALL constructs
                if (construct_type == "if") {
                    condition = get_token_metadata(token_id, "condition")
                    log_debug("parse_content: BEFORE branch_parser, token_id=%d type=%s children=%d condition=[%s] inner_content_length=%d inner_content=[%s]\n", token_id, construct_type, get_children_count(token_id), condition, length(inner_content), substr(inner_content, 1, 100))
                    if (condition ~ /macro_name/) {
                        log_debug("parse_content: outer if, full inner_content=[%s]\n", inner_content)
                    }
                    if (condition ~ /type.*==.*void/) {
                        log_debug("parse_content: nested if BEFORE branch_parser, token_id=%d inner_content_length=%d inner_content=[%s]\n", token_id, length(inner_content), substr(inner_content, 1, 150))
                    }
                }
                if (construct_type == "set") {
                    condition = get_token_metadata(token_id, "condition")
                    log_debug("parse_content: AFTER substr for set, token_id=%d inner_content_length=%d content_start_pos=%d construct_end=%d\n", token_id, length(inner_content), content_start_pos, construct_end)
                    log_debug("parse_content: set, content length=%d content_start_pos=%d\n", length(content), content_start_pos)
                    log_debug("parse_content: set, content from content_start_pos=[%s]\n", substr(content, content_start_pos, 50))
                    log_debug("parse_content: set, inner_content first 100 chars=[%s]\n", substr(inner_content, 1, 100))
                }
                
                # Check if this construct has a branch parser registered
                branch_parser_func = get_branch_parser(construct_type)
                if (branch_parser_func != "") {
                    # Use construct-specific branch parser via dispatch
                    if (construct_type == "set") {
                        log_debug("parse_content: BEFORE dispatch_branch_parser for set, token_id=%d inner_content_length=%d inner_content=[%s]\n", token_id, length(inner_content), substr(inner_content, 1, 200))
                    }
                    if (construct_type == "if") {
                        condition = get_token_metadata(token_id, "condition")
                        if (condition ~ /type.*==.*void/) {
                            log_debug("parse_content: nested if BEFORE dispatch_branch_parser, token_id=%d branch_parser_func=[%s]\n", token_id, branch_parser_func)
                        }
                    }
                    dispatch_3(branch_parser_func, inner_content, token_id, start_line)
                    if (construct_type == "if") {
                        condition = get_token_metadata(token_id, "condition")
                        if (condition ~ /type.*==.*void/) {
                            log_debug("parse_content: nested if AFTER dispatch_branch_parser, token_id=%d children=%d\n", token_id, get_children_count(token_id))
                        }
                    }
                } else {
                    # No branch parser - parse normally
                    if (construct_type == "set") {
                        log_debug("parse_content: BEFORE parse_content for set (no branch parser), token_id=%d inner_content_length=%d inner_content=[%s]\n", token_id, length(inner_content), substr(inner_content, 1, 200))
                        if (DEBUG_ENABLED) {
                            log_debug("parse_content: set hex inner_content=")
                            for (i = 1; i <= 50 && i <= length(inner_content); i++) {
                                c = substr(inner_content, i, 1)
                                if (c == "\n") printf "\\n" > "/dev/stderr"
                                else if (c == "\r") printf "\\r" > "/dev/stderr"
                                else if (c == "\t") printf "\\t" > "/dev/stderr"
                                else printf "%s", c > "/dev/stderr"
                            }
                            printf "\n" > "/dev/stderr"
                        }
                    }
                    parse_content(inner_content, token_id, start_line)
                }
                
                # Debug output for if tokens with type == 'void' condition
                if (construct_type == "if") {
                    condition = get_token_metadata(token_id, "condition")
                    if (condition ~ /type.*==.*void/) {
                        log_debug("parse_content: AFTER branch_parser, token_id=%d type=%s children=%d condition=[%s]\n", token_id, construct_type, get_children_count(token_id), condition)
                    }
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
            # Call tokenizer function via dispatch
            # Note: construct_type is not passed to tokenizer functions
            token_id = dispatch_3(func_name, marker_text, pos, start_line)
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
function find_construct_content(content, start_pos, opening_marker, token_id, construct_type, start_line,    pos, marker_pos, marker_end, marker_text, depth, closing_tag, actual_marker_pos, condition) {
    # Debug output for ALL constructs
    if (construct_type == "if") {
        condition = get_token_metadata(token_id, "condition")
        log_debug("find_construct_content: START, token_id=%d construct_type=%s condition=[%s] start_pos=%d content_length=%d\n", token_id, construct_type, condition, start_pos, length(content))
        if (condition ~ /macro_name/) {
            log_debug("find_construct_content: outer if, content from start_pos=[%s]\n", substr(content, start_pos, 100))
            log_debug("find_construct_content: outer if, full content=[%s]\n", substr(content, 1, 200))
        }
        if (condition ~ /type.*==.*void/) {
            log_debug("find_construct_content: nested if, content_length=%d start_pos=%d\n", length(content), start_pos)
            log_debug("find_construct_content: nested if, content from start_pos=[%s]\n", substr(content, start_pos, 100))
            if (DEBUG_ENABLED) {
                log_debug("find_construct_content: nested if, full content hex: ")
                for (i = 1; i <= length(content) && i <= 150; i++) {
                    c = substr(content, i, 1)
                    if (c == "\n") printf "\\n" > "/dev/stderr"
                    else if (c == "\r") printf "\\r" > "/dev/stderr"
                    else if (c == "\t") printf "\\t" > "/dev/stderr"
                    else printf "%s", c > "/dev/stderr"
                }
                printf "\n" > "/dev/stderr"
            }
        }
    }
    if (construct_type == "set") {
        condition = get_token_metadata(token_id, "condition")
        log_debug("find_construct_content: START for set, token_id=%d condition=[%s] start_pos=%d content_length=%d\n", token_id, condition, start_pos, length(content))
        # Use od -c to see non-printable characters
        if (DEBUG_ENABLED) {
            log_debug("find_construct_content: set, first 50 chars hex: ")
            for (i = 1; i <= 50 && i <= length(content); i++) {
                c = substr(content, i, 1)
                if (c == "\n") printf "\\n" > "/dev/stderr"
                else if (c == "\r") printf "\\r" > "/dev/stderr"
                else if (c == "\t") printf "\\t" > "/dev/stderr"
                else printf "%s", c > "/dev/stderr"
            }
            printf "\n" > "/dev/stderr"
        }
    }
    if (construct_type == "for") {
        condition = get_token_metadata(token_id, "condition")
        log_debug("find_construct_content: START for for, token_id=%d condition=[%s] start_pos=%d content_length=%d\n", token_id, condition, start_pos, length(content))
        log_debug("find_construct_content: for, content from start_pos=[%s]\n", substr(content, start_pos, 100))
    }
    
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
        if (construct_type == "if") {
            condition = get_token_metadata(token_id, "condition")
            if (condition ~ /type.*==.*void/) {
                log_debug("find_construct_content: NO closing tag, returning 0\n")
            }
        }
        if (construct_type == "set") {
            log_debug("find_construct_content: set NO closing tag, returning 0\n")
        }
        return 0
    }
    
    # Debug output for set tokens
    if (construct_type == "set") {
        log_debug("find_construct_content: set closing_tag=[%s]\n", closing_tag)
    }
    # Debug output for nested if tokens
    if (construct_type == "if") {
        condition = get_token_metadata(token_id, "condition")
        if (condition ~ /type.*==.*void/) {
            log_debug("find_construct_content: nested if closing_tag=[%s]\n", closing_tag)
        }
    }
    
    # Remove ^ and $ from pattern for matching
    closing_pattern = closing_tag
    # Remove ^ at the beginning
    if (substr(closing_pattern, 1, 1) == "^") {
        closing_pattern = substr(closing_pattern, 2)
    }
    # Remove $ at the end
    if (substr(closing_pattern, length(closing_pattern)) == "$") {
        closing_pattern = substr(closing_pattern, 1, length(closing_pattern) - 1)
    }
    
    # Escape special regex characters in closing_pattern
    # This is necessary because closing_pattern is used in match() which treats it as a regex
    escaped_closing_pattern = closing_pattern
    gsub(/[.*+?^${}()|[\]\\]/, "\\\\&", escaped_closing_pattern)
    closing_pattern = escaped_closing_pattern
    
    # Debug output for set tokens
    if (construct_type == "set") {
        log_debug("find_construct_content: set closing_pattern=[%s] after removal and escaping\n", closing_pattern)
    }
    # Debug output for nested if tokens
    if (construct_type == "if") {
        condition = get_token_metadata(token_id, "condition")
        if (condition ~ /type.*==.*void/) {
            log_debug("find_construct_content: nested if closing_pattern=[%s] after removal and escaping\n", closing_pattern)
        }
    }
    
    depth = 1
    pos = start_pos
    
    while (pos <= length(content)) {
        marker_pos = match(substr(content, pos), /{{/)
        if (marker_pos == 0) {
            # Debug output for if tokens with type == 'void' condition
            if (construct_type == "if") {
                condition = get_token_metadata(token_id, "condition")
                if (condition ~ /type.*==.*void/) {
                    log_debug("find_construct_content: no more markers, pos=%d content_length=%d, returning 0\n", pos, length(content))
                }
            }
            break
        }
        
        actual_marker_pos = pos + marker_pos - 1
        marker_end = find_matching_close(content, actual_marker_pos)
        if (marker_end == 0) {
            pos = actual_marker_pos + 2
            continue
        }
        
        marker_text = substr(content, actual_marker_pos + 2, marker_end - 1)
        
        # Debug output for nested if tokens
        if (construct_type == "if") {
            condition = get_token_metadata(token_id, "condition")
            if (condition ~ /type.*==.*void/) {
                log_debug("find_construct_content: nested if marker at pos=%d marker_text=[%s] depth=%d\n", actual_marker_pos, marker_text, depth)
            }
        }
        
        # Debug output for set tokens
        if (construct_type == "set" && actual_marker_pos >= 250 && actual_marker_pos <= 270) {
            log_debug("find_construct_content: set marker at pos=%d marker_text=[%s] marker_end=%d\n", actual_marker_pos, marker_text, marker_end)
            log_debug("find_construct_content: set content around pos=[%s]\n", substr(content, actual_marker_pos - 5, 20))
            # Show hex representation
            if (DEBUG_ENABLED) {
                log_debug("find_construct_content: set hex around pos=")
                for (i = actual_marker_pos - 5; i <= actual_marker_pos + 20 && i <= length(content); i++) {
                    c = substr(content, i, 1)
                    if (c == "\n") printf "\\n" > "/dev/stderr"
                    else if (c == "\r") printf "\\r" > "/dev/stderr"
                    else if (c == "\t") printf "\\t" > "/dev/stderr"
                    else printf "%s", c > "/dev/stderr"
                }
                printf "\n" > "/dev/stderr"
            }
        }
        
        # Debug output for if tokens with type == 'void' condition
        if (construct_type == "if") {
            condition = get_token_metadata(token_id, "condition")
            if (condition ~ /type.*==.*void/ && depth <= 2) {
                log_debug("find_construct_content: marker_text=[%s] depth=%d\n", marker_text, depth)
            }
        }
        
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
        if (construct_type == "if") {
            condition = get_token_metadata(token_id, "condition")
            if (condition ~ /type.*==.*void/) {
                match_result = match(marker_text, closing_pattern)
                log_debug("find_construct_content: nested if checking match, marker_text=[%s] closing_pattern=[%s] match_result=%d\n", marker_text, closing_pattern, match_result)
            }
        }
        if (match(marker_text, closing_pattern)) {
            depth--
            # Debug output for set tokens
            if (construct_type == "set") {
                log_debug("find_construct_content: set found closing tag, marker_text=[%s] closing_pattern=[%s] depth=%d\n", marker_text, closing_pattern, depth)
            }
            # Debug output for nested if tokens
            if (construct_type == "if") {
                condition = get_token_metadata(token_id, "condition")
                if (condition ~ /type.*==.*void/) {
                    log_debug("find_construct_content: nested if found closing tag, marker_text=[%s] closing_pattern=[%s] depth=%d\n", marker_text, closing_pattern, depth)
                }
            }
            # Debug output for if tokens with type == 'void' condition
            if (construct_type == "if" && depth == 0) {
                condition = get_token_metadata(token_id, "condition")
                if (condition ~ /type.*==.*void/) {
                    log_debug("find_construct_content: found closing tag at depth=0, actual_marker_pos=%d construct_type=%s marker_text=[%s]\n", actual_marker_pos, construct_type, marker_text)
                }
            }
            if (depth == 0) {
                # Debug output for set tokens
                if (construct_type == "set") {
                    log_debug("find_construct_content: set found closing tag at depth=0, returning actual_marker_pos=%d\n", actual_marker_pos)
                }
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
                # Debug output for if tokens with type == 'void' condition
                if (construct_type == "if") {
                    condition = get_token_metadata(token_id, "condition")
                    if (condition ~ /type.*==.*void/) {
                        log_debug("find_construct_content: found branch marker at depth=1, marker_text=[%s] construct_type=%s\n", marker_text, construct_type)
                    }
                }
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

