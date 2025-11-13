# Renderer - Renders evaluated token tree to final text
# Single point of rendering - converts AST to output text
# Uses registry-based callback system for extensible rendering

@include "core/token_tree.awk"
@include "core/construct_registry.awk"

# Render a token tree to text
# Parameters:
#   token_id - token ID to render
# Returns: rendered text
function render_token(token_id,    token_type, renderer_func, result, child_count, i, child_id, child_text) {
    if (!token_exists(token_id)) {
        return ""
    }
    
    token_type = get_token_type(token_id)
    
    # Get renderer function from registry
    renderer_func = get_renderer_function(token_type)
    
    if (renderer_func != "") {
        # Use registered renderer function via indirect call
        result = @renderer_func(token_id)
        return result
    }
    
    # No renderer registered - default behavior: render children
    result = ""
    child_count = get_children_count(token_id)
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_text = render_token(child_id)
        result = result child_text
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

