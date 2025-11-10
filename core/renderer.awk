# Renderer - Renders evaluated token tree to final text
# Single point of rendering - converts AST to output text

@include "core/token_tree.awk"

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
    else if (token_type == "root") {
        # Root token - render all children
        child_count = get_children_count(token_id)
        for (i = 1; i <= child_count; i++) {
            child_id = get_child(token_id, i)
            child_text = render_token(child_id)
            result = result child_text
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

