# Variable Token Renderer
# Renders variable tokens - reconstructs {{VAR}} syntax for template preservation

@include "core/token_tree.awk"

# Render a variable token
# Parameters:
#   token_id - token ID to render
# Returns: rendered text ({{VAR}} syntax)
function render_var_token(token_id,    var_name) {
    var_name = get_token_metadata(token_id, "var_name")
    if (var_name != "") {
        return "{{" var_name "}}"
    }
    return ""
}

