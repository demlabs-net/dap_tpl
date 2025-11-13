# Renderer - Renders evaluated token tree to final text
# Single point of rendering - converts AST to output text

@include "core/token_tree.awk"
@include "core/construct_registry.awk"

# Render a token tree to text
# Parameters:
#   token_id - token ID to render
# Returns: rendered text
function render_token(token_id,    token_type, result, child_count, i, child_id, child_text) {
    if (!token_exists(token_id)) {
        return ""
    }
    
    token_type = get_token_type(token_id)
    result = ""
    
    # Render based on token type
    if (token_type == "text") {
        # Text token - return value directly
        result = get_token_value(token_id)
    }
    else if (token_type == "var") {
        # Variable token - reconstruct {{VAR}} syntax for template preservation
        var_name = get_token_metadata(token_id, "var_name")
        if (var_name != "") {
            result = "{{" var_name "}}"
        }
    }
    else if (token_type == "root") {
        # Root token - render all children
        child_count = get_children_count(token_id)
        prev_was_empty = 0
        for (i = 1; i <= child_count; i++) {
            child_id = get_child(token_id, i)
            child_type = get_token_type(child_id)
            child_text = render_token(child_id)
            
            # Skip empty text tokens if marked to skip (from comments, etc.)
            # Check metadata first, then registry as fallback
            skip_empty = get_token_metadata(child_id, "skip_empty_text")
            if (skip_empty == "" || skip_empty == "0") {
                # Check registry for construct type that produced this token
                # Note: We can't directly know which construct produced a text token,
                # so we rely on metadata set by the evaluator
                skip_empty = "0"
            }
            
            if (child_type == "text" && child_text == "" && skip_empty == "1") {
                # Empty text token marked to skip - skip it
                prev_was_empty = 1
                continue
            }
            
            # If previous was empty and current starts with newline, skip the newline
            if (prev_was_empty && child_text ~ /^\n/) {
                child_text = substr(child_text, 2)
            }
            
            result = result child_text
            prev_was_empty = 0
        }
    }
    else {
        # Other token types - render children
        child_count = get_children_count(token_id)
        for (i = 1; i <= child_count; i++) {
            child_id = get_child(token_id, i)
            child_text = render_token(child_id)
            result = result child_text
        }
    }
    
    return result
}

# Render entire tree starting from root
# Parameters:
#   root_token_id - root token ID
# Returns: rendered text
function render_tree(root_token_id) {
    return render_token(root_token_id)
}

