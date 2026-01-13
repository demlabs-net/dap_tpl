# Variable Token Renderer
# Renders variable tokens - returns evaluated value
# Note: Variable tokens should be evaluated before rendering (via evaluate_var)
# This renderer is a fallback in case evaluation didn't happen

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"
@include "core/debug.awk"

# Render a variable token
# Parameters:
#   token_id - token ID to render
# Returns: evaluated value (or empty string if not found)
function render_var_token(token_id,    var_name, parsed_expr, var_name_parsed, func_name, func_arg, base_value, result_value) {
    var_name = get_token_metadata(token_id, "var_name")
    if (var_name == "") {
        return ""
    }
    
    # Parse variable expression
    parsed_expr = parse_var_expr(var_name)
    var_name_parsed = get_var_name(parsed_expr)
    func_name = get_func_name(parsed_expr)
    func_arg = get_func_arg(parsed_expr)
    
    # Get base value from context
    base_value = get_var(var_name_parsed)
    
    # Process function if present
    if (func_name != "") {
        result_value = process_variable_function(var_name_parsed, func_name, func_arg, base_value)
    } else {
        result_value = base_value
    }
    
    return result_value
}

