# In List Operator Parser
# Parses: left in right

# Parse in list: left in right
# Parameters:
#   expr - expression string containing 'in'
# Returns: parsed condition structure "in|left|right"
function parse_in_list(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+in[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    result = "in|" parse_simple_var(left) "|" parse_simple_var(right)
    return result
}

