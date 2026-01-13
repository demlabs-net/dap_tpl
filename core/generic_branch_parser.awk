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
# NODISPATCH: uses array parameter
function find_branches_generic(content, construct_type, positions,    pos, marker_pos, marker_end, marker_text, count, actual_pos, pattern, token_type, condition_match, depth, closing_tag, closing_pattern) {
    delete positions
    count = 0
    pos = 1
    depth = 0
    
    # Get closing tag pattern for depth tracking
    closing_tag = ""
    for (tag in CLOSING_PATTERNS) {
        if (CLOSING_PATTERNS[tag] == construct_type) {
            closing_tag = tag
            break
        }
    }
    
    # Prepare closing pattern for matching (remove ^ and $, escape special chars)
    if (closing_tag != "") {
        closing_pattern = closing_tag
        if (substr(closing_pattern, 1, 1) == "^") {
            closing_pattern = substr(closing_pattern, 2)
        }
        if (substr(closing_pattern, length(closing_pattern)) == "$") {
            closing_pattern = substr(closing_pattern, 1, length(closing_pattern) - 1)
        }
        # Escape special regex characters
        escaped_closing_pattern = closing_pattern
        gsub(/[.*+?^${}()|[\]\\]/, "\\\\&", escaped_closing_pattern)
        closing_pattern = escaped_closing_pattern
    }
    
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
        
        # Track depth for nested constructs of the same type
        if (closing_pattern != "" && match(marker_text, closing_pattern)) {
            depth--
        } else {
            # Check if this is an opening tag of the same construct type
            for (pattern_type in CONSTRUCT_PATTERNS) {
                if (pattern_type == construct_type) {
                    pattern = CONSTRUCT_PATTERNS[pattern_type]
                    if (match(marker_text, pattern)) {
                        depth++
                        break
                    }
                }
            }
        }
        
        # Check if this is a branch marker for the construct using registry
        # Only consider branch markers at top level (depth == 0)
        if (depth == 0 && is_branch_marker(construct_type, marker_text)) {
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
function parse_branches_generic(content, token_id, construct_type, start_line,    positions, count, i, current_pos, next_pos, branch_content, branch_token_id, metadata, marker_end, condition) {
    # Debug output - ALWAYS print for if constructs with type == 'void' condition
    if (construct_type == "if") {
        condition = get_token_metadata(token_id, "condition")
        if (condition ~ /type.*==.*void/) {
            log_debug("parse_branches_generic: START, token_id=%d construct_type=%s content_length=%d content=[%s]\n", token_id, construct_type, length(content), substr(content, 1, 150))
        }
    }
    # Debug output for set constructs
    if (construct_type == "set") {
        log_debug("parse_branches_generic: START for set, token_id=%d construct_type=%s content_length=%d content=[%s]\n", token_id, construct_type, length(content), substr(content, 1, 200))
    }
    
    delete positions
    count = find_branches_generic(content, construct_type, positions)
    
    # Debug output for outer if with macro_name condition
    if (construct_type == "if") {
        condition = get_token_metadata(token_id, "condition")
        if (condition ~ /macro_name/) {
            log_debug("parse_branches_generic: find_branches_generic returned count=%d\n", count)
            log_debug("parse_branches_generic: full content length=%d\n", length(content))
            if (DEBUG_ENABLED) {
                log_debug("parse_branches_generic: full content hex: ")
                for (i = 1; i <= 250 && i <= length(content); i++) {
                    c = substr(content, i, 1)
                    if (c == "\n") printf "\\n" > "/dev/stderr"
                    else if (c == "\r") printf "\\r" > "/dev/stderr"
                    else if (c == "\t") printf "\\t" > "/dev/stderr"
                    else printf "%s", c > "/dev/stderr"
                }
                printf "\n" > "/dev/stderr"
            }
            if (count > 0) {
                log_debug("parse_branches_generic: first branch position=%d type=[%s]\n", positions[1, "pos"], positions[1, "type"])
                if (DEBUG_ENABLED) {
                    log_debug("parse_branches_generic: content before first branch hex: ")
                    for (i = 1; i <= positions[1, "pos"] - 1 && i <= 250; i++) {
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
    }
    
    # Debug output - ALWAYS print for if constructs
    if (construct_type == "if") {
        log_debug("parse_branches_generic: token_id=%d construct_type=%s count=%d content_length=%d\n", token_id, construct_type, count, length(content))
        condition = get_token_metadata(token_id, "condition")
        if (condition ~ /type.*==.*void/) {
            log_debug("parse_branches_generic: nested if detected, count=%d content=[%s]\n", count, substr(content, 1, 150))
            log_debug("parse_branches_generic: token_id=%d construct_type=%s count=%d content_length=%d", token_id, construct_type, count, length(content))
        }
    }
    
    if (count == 0) {
        # No branches - parse normally
        if (construct_type == "if") {
            log_debug("parse_branches_generic: NO BRANCHES, parsing normally\n")
            if (content ~ /type.*==.*void/) {
                log_debug("parse_branches_generic: nested if NO BRANCHES, content=[%s]\n", substr(content, 1, 100))
            }
        }
        parse_content(content, token_id, start_line)
        
        # Debug output
        if (construct_type == "if") {
            log_debug("parse_branches_generic: after parse_content, token_id=%d children=%d\n", token_id, get_children_count(token_id))
        }
        if (construct_type == "if" && content ~ /type.*==.*void/) {
            log_debug("after parse_content, token_id=%d children=%d", token_id, get_children_count(token_id))
        }
        return
    }
    
    current_pos = 1
    
    # Parse main branch (before first branch marker)
    next_pos = positions[1, "pos"]
    branch_content = substr(content, current_pos, next_pos - current_pos)
    
    # Debug output - ALWAYS print for if constructs
    if (construct_type == "if") {
        log_debug("parse_branches_generic: parsing main branch, content=[%s]\n", branch_content)
        # Check if this is nested if with type == 'void'
        if (content ~ /type.*==.*void/) {
            log_debug("parse_branches_generic: nested if detected, branch_content length=%d\n", length(branch_content))
        }
        # Check if this is outer if with macro_name condition
        condition = get_token_metadata(token_id, "condition")
        if (condition ~ /macro_name/) {
            log_debug("parse_branches_generic: outer if, branch_content length=%d branch_content=[%s]\n", length(branch_content), substr(branch_content, 1, 150))
            if (DEBUG_ENABLED) {
                log_debug("parse_branches_generic: outer if, branch_content hex: ")
                for (i = 1; i <= 200 && i <= length(branch_content); i++) {
                    c = substr(branch_content, i, 1)
                    if (c == "\n") printf "\\n" > "/dev/stderr"
                    else if (c == "\r") printf "\\r" > "/dev/stderr"
                    else if (c == "\t") printf "\\t" > "/dev/stderr"
                    else printf "%s", c > "/dev/stderr"
                }
                printf "\n" > "/dev/stderr"
            }
        }
    }
    if (construct_type == "if" && content ~ /type.*==.*void/) {
        log_debug("parsing main branch, content=[%s]", branch_content)
    }
    
    parse_content(branch_content, token_id, start_line)
    
    # Debug output
    if (construct_type == "if") {
        log_debug("parse_branches_generic: after main branch, token_id=%d children=%d\n", token_id, get_children_count(token_id))
        # Check nested if tokens
        if (content ~ /type.*==.*void/) {
            child_count = get_children_count(token_id)
            for (j = 1; j <= child_count; j++) {
                child_id = get_child(token_id, j)
                child_type = get_token_type(child_id)
                if (child_type == "if") {
                    child_condition = get_token_metadata(child_id, "condition")
                    child_children = get_children_count(child_id)
                    log_debug("parse_branches_generic: nested if child[%d]=%d type=%s children=%d condition=[%s]\n", j, child_id, child_type, child_children, child_condition)
                }
            }
        }
    }
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
        
        # Debug output - ALWAYS print for if constructs
        if (construct_type == "if") {
            log_debug("parse_branches_generic: added branch %s (id=%d), branch_children=%d total_children=%d\n", positions[i, "type"], branch_token_id, get_children_count(branch_token_id), get_children_count(token_id))
        }
        if (construct_type == "if" && content ~ /type.*==.*void/) {
            log_debug("added branch %s, branch_children=%d total_children=%d", positions[i, "type"], get_children_count(branch_token_id), get_children_count(token_id))
        }
    }
    
    # Store metadata indicating branches were found
    set_token_metadata(token_id, "has_branches", "1")
    
    # Debug output
    if (construct_type == "if") {
        log_debug("parse_branches_generic: final token_id=%d children=%d\n", token_id, get_children_count(token_id))
        condition = get_token_metadata(token_id, "condition")
        if (condition ~ /type.*==.*void/) {
            log_debug("parse_branches_generic: nested if final, token_id=%d children=%d condition=[%s]\n", token_id, get_children_count(token_id), condition)
            # List all children
            child_count = get_children_count(token_id)
            for (j = 1; j <= child_count; j++) {
                child_id = get_child(token_id, j)
                child_type = get_token_type(child_id)
                child_children = get_children_count(child_id)
                log_debug("parse_branches_generic: nested if child[%d]=%d type=%s children=%d\n", j, child_id, child_type, child_children)
            }
        }
    }
    if (construct_type == "if" && content ~ /type.*==.*void/) {
        log_debug("final token_id=%d children=%d", token_id, get_children_count(token_id))
    }
}

