# Root Token Renderer
# Renders root tokens - processes all children with filtering and normalization

@include "core/token_tree.awk"
@include "core/construct_registry.awk"
@include "core/debug.awk"
@include "core/renderer.awk"

# Render a root token
# Parameters:
#   token_id - token ID to render
# Returns: rendered text (all children concatenated)
function render_root_token(token_id,    child_count, i, child_id, child_type, child_text, result, prev_type, prev_text, next_type, prev_child_id, next_child_id, skip_empty, filtered_result, prev_was_empty, prev_prev_child_id, prev_prev_type, filter_func, modified_value, cleaned_result, iterations, marker_start, marker_end, depth, j, original_length, pos) {
    child_count = get_children_count(token_id)
    result = ""
    prev_was_empty = 0
    
    # Debug output (disabled by default - set DEBUG_RENDER=1 to enable)
    # Always debug for root tokens with children that render empty
    if (child_count > 0) {
        # printf "DEBUG render_root_token: token_id=%d children=%d\n", token_id, child_count > "/dev/stderr"
    }
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        if (child_id == 0) {
            continue
        }
        child_type = get_token_type(child_id)
        child_text = render_token(child_id)
        
        # Skip empty tokens if marked to skip (based on metadata, not type)
        skip_empty = get_token_metadata(child_id, "skip_empty_text")
        if (skip_empty == "1" && child_text == "") {
            # Empty token marked to skip - skip it
            prev_was_empty = 1
            continue
        }
        
        # Get previous and next token types and values for context
        prev_type = ""
        prev_text = ""
        next_type = ""
        prev_prev_type = ""
        prev_prev_text = ""
        
        if (i > 1) {
            prev_child_id = get_child(token_id, i - 1)
            prev_type = get_token_type(prev_child_id)
            prev_text = render_token(prev_child_id)
            
            # Check token before previous for context (e.g., set -> \n -> text)
            if (i > 2 && prev_type == "text" && prev_text == "\n") {
                prev_prev_child_id = get_child(token_id, i - 2)
                prev_prev_type = get_token_type(prev_prev_child_id)
                prev_prev_text = render_token(prev_prev_child_id)
            }
        }
        if (i < child_count) {
            next_child_id = get_child(token_id, i + 1)
            next_type = get_token_type(next_child_id)
        }
        
        # Process child token using registered processors (universal, not type-specific)
        processed_result = process_child_token(child_text, child_type, prev_type, prev_text, next_type)
        if (processed_result == "SKIP") {
            # Debug output disabled by default - use DEBUG_ENABLED to enable
            # if (DEBUG_ENABLED && (child_text ~ /VOID|NON-VOID/ || child_type == "var")) {
            #     log_debug("render_root_token: child[%d] SKIPPED by process_child_token, type=%s text=[%s] prev_type=%s prev_text=[%s]", i, child_type, child_text, prev_type, prev_text)
            # }
            continue
        } else if (processed_result != "") {
            child_text = processed_result
        }
        
        # Special case: if previous token is text with only newline, check token before that
        # This handles cases like: set -> \n -> " Text" where we need to remove space
        # Use processor for token before newline to handle this case
        if (prev_type == "text" && prev_text == "\n" && prev_prev_type != "") {
            # Try processor for token before newline (e.g., set -> \n -> text)
            processed_result = process_text_token(child_text, prev_prev_type, prev_prev_text, next_type)
            if (processed_result == "SKIP") {
                # Debug output disabled by default - use DEBUG_ENABLED to enable
                # if (DEBUG_ENABLED && (child_text ~ /VOID|NON-VOID/ || child_type == "var")) {
                #     log_debug("render_root_token: child[%d] SKIPPED by process_text_token, type=%s text=[%s]", i, child_type, child_text)
                # }
                continue
            } else if (processed_result != "") {
                child_text = processed_result
            }
        }
        
        # Check if text token should be filtered using registered filters (for text tokens only)
        if (child_type == "text") {
            filtered_result = filter_text_token(child_text, prev_type, prev_text, next_type)
            if (filtered_result == "SKIP") {
                # Debug output disabled by default - use DEBUG_ENABLED to enable
                # if (DEBUG_ENABLED && child_text ~ /VOID|NON-VOID/) {
                #     log_debug("render_root_token: child[%d] SKIPPED by filter_text_token, type=%s text=[%s]", i, child_type, child_text)
                # }
                continue
            } else if (filtered_result != "") {
                # Filter returned modified value - use it
                child_text = filtered_result
            }
        }
        
        # If previous was empty and current starts with newline, skip the newline
        if (prev_was_empty && child_text ~ /^\n/) {
            child_text = substr(child_text, 2)
        }
        
        result = result child_text
        prev_was_empty = 0
        
        # Debug output disabled by default - use DEBUG_ENABLED to enable
        # if (DEBUG_ENABLED && child_count > 0 && length(result) == 0 && i <= 3) {
        #     log_debug("render_root_token: child[%d] type=%s text=[%s] text_length=%d result_so_far=[%s] skip_empty=%s", i, child_type, child_text, length(child_text), result, skip_empty)
        # }
    }
    
    # Debug output disabled by default - use DEBUG_ENABLED to enable
    # if (DEBUG_ENABLED && child_count > 0 && length(result) == 0) {
    #     log_debug("render_root_token: FINAL result=[%s] length=%d token_id=%d children=%d", result, length(result), token_id, child_count)
    # }
    
    # Final cleanup: remove any remaining construct markers that shouldn't be in output
    # This is a safety net in case some markers weren't removed during token rendering
    # Use find_matching_close logic to handle multiline markers
    cleaned_result = result
    iterations = 0
    original_length = length(cleaned_result)
    # Search for construct markers manually (match() may not work correctly for multiline)
    pos = 1
    while (pos <= length(cleaned_result) - 3 && iterations < 100) {
        # Look for {{# or {{/
        if (substr(cleaned_result, pos, 2) == "{{" && (substr(cleaned_result, pos + 2, 1) == "#" || substr(cleaned_result, pos + 2, 1) == "/")) {
            marker_start = pos
            # Find matching }} accounting for nested markers
            depth = 0
            marker_end = 0
            for (j = marker_start + 2; j <= length(cleaned_result) - 1; j++) {
                if (substr(cleaned_result, j, 2) == "{{") {
                    depth++
                    j++  # Skip second {
                } else if (substr(cleaned_result, j, 2) == "}}") {
                    if (depth == 0) {
                        marker_end = j + 1  # Position after }}
                        break
                    }
                    depth--
                    j++  # Skip second }
                }
            }
            if (marker_end > 0) {
                cleaned_result = substr(cleaned_result, 1, marker_start - 1) substr(cleaned_result, marker_end + 1)
                iterations++
                # Don't advance pos - check same position again in case there's another marker
                continue
            } else {
                # No matching }} found - remove from marker_start to end
                cleaned_result = substr(cleaned_result, 1, marker_start - 1)
                break
            }
        }
        pos++
    }
    
    # If markers were removed, log it
    if (length(cleaned_result) != original_length) {
        log_debug("render_root_token: removed construct markers, original_length=%d cleaned_length=%d iterations=%d", original_length, length(cleaned_result), iterations)
    }
    
    return cleaned_result
}

