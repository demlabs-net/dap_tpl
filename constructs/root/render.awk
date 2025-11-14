# Root Token Renderer
# Renders root tokens - processes all children with filtering and normalization

@include "core/token_tree.awk"
@include "core/construct_registry.awk"
@include "core/renderer.awk"

# Render a root token
# Parameters:
#   token_id - token ID to render
# Returns: rendered text (all children concatenated)
function render_root_token(token_id,    child_count, i, child_id, child_type, child_text, result, prev_type, prev_text, next_type, prev_child_id, next_child_id, skip_empty, filtered_result, prev_was_empty, prev_prev_child_id, prev_prev_type, filter_func, modified_value) {
    child_count = get_children_count(token_id)
    result = ""
    prev_was_empty = 0
    
    # Debug output (disabled by default - set DEBUG_RENDER=1 to enable)
    # if (ENVIRON["DEBUG_RENDER"] == "1") {
    #     printf "DEBUG render_root_token: token_id=%d children=%d\n", token_id, child_count > "/dev/stderr"
    # }
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
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
                continue
            } else if (processed_result != "") {
                child_text = processed_result
            }
        }
        
        # Check if text token should be filtered using registered filters (for text tokens only)
        if (child_type == "text") {
            filtered_result = filter_text_token(child_text, prev_type, prev_text, next_type)
            if (filtered_result == "SKIP") {
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
        
        # Debug output (disabled by default - set DEBUG_RENDER=1 to enable)
        # if (ENVIRON["DEBUG_RENDER"] == "1" && i <= 3) {
        #     printf "DEBUG render_root_token: child[%d] type=%s text=[%s] result_so_far=[%s]\n", i, child_type, child_text, result > "/dev/stderr"
        # }
    }
    
    # Debug output (disabled by default - set DEBUG_RENDER=1 to enable)
    # if (ENVIRON["DEBUG_RENDER"] == "1") {
    #     printf "DEBUG render_root_token: FINAL result=[%s] length=%d\n", result, length(result) > "/dev/stderr"
    # }
    
    return result
}

