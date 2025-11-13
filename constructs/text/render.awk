# Text Token Renderer
# Renders text tokens - returns value directly

@include "core/token_tree.awk"

# Render a text token
# Parameters:
#   token_id - token ID to render
# Returns: rendered text (token value)
function render_text_token(token_id) {
    return get_token_value(token_id)
}

