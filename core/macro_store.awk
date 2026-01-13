# Macro Store - stores and retrieves template macros
# Macros are reusable template fragments that can be called with parameters

BEGIN {
    # Global macro storage
    # Format: macros["macro_name"] = "template content"
    # Format: macros["macro_name_param_0"] = "param1"
    # Format: macros["macro_name_param_1"] = "param2"
    # etc.
}

# Store macro definition
# Parameters:
#   macro_name - name of macro
#   macro_content - template content of macro
function store_macro(macro_name, macro_content) {
    macros[macro_name] = macro_content
    macros[macro_name "_defined"] = 1
}

# Check if macro is defined
# Parameters:
#   macro_name - name of macro
# Returns: 1 if defined, 0 otherwise
function is_macro_defined(macro_name) {
    return (macro_name "_defined" in macros) ? 1 : 0
}

# Get macro content
# Parameters:
#   macro_name - name of macro
# Returns: macro content or empty string if not defined
function get_macro(macro_name) {
    if (is_macro_defined(macro_name)) {
        return macros[macro_name]
    }
    return ""
}

# Expand macro with parameters
# Parameters:
#   macro_name - name of macro
#   param_count - number of parameters
#   params - array of parameter values (params[0], params[1], ...)
# Returns: expanded macro content
# NODISPATCH: takes array parameter
function expand_macro(macro_name, param_count, params,    macro_content, i, param_var, param_value, result) {
    macro_content = get_macro(macro_name)
    if (macro_content == "") {
        return ""
    }
    
    # Replace parameter placeholders {{ARG0}}, {{ARG1}}, etc. with actual values
    # Need to escape special regex characters in param_var
    result = macro_content
    for (i = 0; i < param_count; i++) {
        param_var = "{{ARG" i "}}"
        # Escape special regex characters: { } are literal in gsub
        # But we need to match them exactly, so use index() and substr() for safety
        # Or escape them properly: { and } need to be escaped as \{ and \}
        escaped_var = param_var
        gsub(/[{}]/, "\\\\&", escaped_var)  # Escape { and } for regex
        param_value = params[i]
        gsub(escaped_var, param_value, result)
    }
    
    return result
}

