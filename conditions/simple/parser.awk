# Simple Variable Parser
# Parses: VAR (simple variable check for truthiness)

# Parse simple variable (may have function calls)
# Parameters:
#   expr - variable expression (e.g., VAR, VAR|len, VAR|split|pipe)
# Returns: parsed variable expression with || delimiter preserved
function parse_simple_var(expr) {
    # For simple variables, parse through marker parser and return formatted string
    # This preserves the marker parser format VAR||func||arg
    return parse_var_expr(expr)
}
